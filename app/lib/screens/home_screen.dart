import 'package:flutter/material.dart';

import '../blockchain/candle_clash_program.dart';
import '../blockchain/solana_service.dart';
import '../blockchain/wallet_service.dart';
import '../config/constants.dart';
import '../models/player_profile.dart';
import '../models/player_vault.dart';
import 'widgets/clash_widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final wallet = WalletService();
  final solana = SolanaService();
  final program = CandleClashProgram();

  String? address;
  double walletSol = 0;
  PlayerVault vault = PlayerVault.empty;
  PlayerProfile profile = PlayerProfile.empty;
  bool busy = false;
  String status = 'Connect a Solana Mobile wallet to enter the arena.';

  Future<void> connect() async {
    setState(() {
      busy = true;
      status = 'Opening wallet...';
    });
    try {
      final connection = await wallet.connect();
      if (connection == null) {
        setState(() => status = 'Wallet connection cancelled or unavailable.');
        return;
      }
      final balance = await solana.getSolBalance(connection.address);
      final fetchedVault = await program.fetchVault(connection.address);
      final fetchedProfile = await program.fetchProfile(connection.address);
      setState(() {
        address = connection.address;
        walletSol = balance;
        vault = fetchedVault;
        profile = fetchedProfile;
        status = 'Connected as ${WalletUtils.shortAddress(connection.address)}';
      });
    } catch (error) {
      setState(() => status = '$error');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final connected = address != null;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          children: [
            Row(
              children: [
                const ClashLogo(height: 78),
                const Spacer(),
                _BalancePill(sol: vault.balanceLamports == 0 ? walletSol : vault.balanceLamports / AppConstants.lamportsPerSol),
              ],
            ),
            const SizedBox(height: 18),
            ClashPanel(
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(
                        connected ? WalletUtils.shortAddress(address!) : 'NO WALLET',
                        style: const TextStyle(color: clashGreen, fontWeight: FontWeight.w800, letterSpacing: 1),
                      ),
                      const Spacer(),
                      Text('ROUND #${program.currentUtcDayId()}', style: const TextStyle(color: Colors.white54)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'WILL THE NEXT CANDLE',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, letterSpacing: 1.5),
                  ),
                  const SizedBox(height: 4),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('RISE', style: TextStyle(color: clashGreen, fontSize: 38, fontWeight: FontWeight.w900)),
                      SizedBox(width: 10),
                      Text('OR', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
                      SizedBox(width: 10),
                      Text('FALL?', style: TextStyle(color: clashRed, fontSize: 38, fontWeight: FontWeight.w900)),
                    ],
                  ),
                  const SizedBox(height: 18),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      'assets/images/game_reference.jpeg',
                      height: 190,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                    ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: busy ? null : connect,
                    icon: const Icon(Icons.account_balance_wallet),
                    label: Text(connected ? 'REFRESH WALLET' : 'CONNECT WALLET'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(54),
                      backgroundColor: clashGreen,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  FilledButton.tonalIcon(
                    onPressed: connected ? () => Navigator.pushNamed(context, '/game') : null,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('PLAY'),
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                NeonStat(icon: Icons.emoji_events, label: 'Points', value: '${profile.exp}', color: clashYellow),
                const SizedBox(width: 10),
                NeonStat(icon: Icons.local_fire_department, label: 'Streak', value: '${profile.currentStreak}', color: clashRed),
                const SizedBox(width: 10),
                NeonStat(icon: Icons.trending_up, label: 'Level', value: '${profile.level}', color: clashGreen),
              ],
            ),
            const SizedBox(height: 14),
            ClashPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('WALLET', style: TextStyle(color: Colors.white70, letterSpacing: 1.2)),
                  const SizedBox(height: 10),
                  Text('SOL balance: ${walletSol.toStringAsFixed(4)}'),
                  Text('Internal balance: ${_sol(vault.balanceLamports)} SOL'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: FilledButton(onPressed: connected ? () => _comingSoon('Deposit') : null, child: const Text('DEPOSIT'))),
                      const SizedBox(width: 10),
                      Expanded(child: OutlinedButton(onPressed: connected ? () => _comingSoon('Withdraw') : null, child: const Text('WITHDRAW'))),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(status, style: const TextStyle(color: Colors.white70)),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const ClashBottomNav(current: 'play'),
    );
  }

  void _comingSoon(String action) {
    setState(() => status = '$action will use the generated Anchor IDL transaction builder.');
  }

  String _sol(int lamports) => (lamports / AppConstants.lamportsPerSol).toStringAsFixed(4);
}

class _BalancePill extends StatelessWidget {
  const _BalancePill({required this.sol});

  final double sol;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: clashBorder),
        borderRadius: BorderRadius.circular(8),
        color: const Color(0xff0b121b),
      ),
      child: Row(
        children: [
          const Icon(Icons.token, color: clashPurple, size: 20),
          const SizedBox(width: 8),
          Text('${sol.toStringAsFixed(2)} SOL', style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
