import 'package:flutter/material.dart';

import '../blockchain/candle_clash_program.dart';
import '../blockchain/solana_service.dart';
import '../blockchain/wallet_service.dart';
import '../config/constants.dart';
import '../models/player_profile.dart';
import '../models/player_vault.dart';

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
  String status = 'Visual price is not settlement price. Pyth onchain settles rounds.';

  Future<void> connect() async {
    setState(() => busy = true);
    try {
      final connection = await wallet.connect();
      if (connection == null) {
        setState(() => status = 'No compatible Solana Mobile wallet found.');
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
        status = 'Wallet connected. Initialize/deposit transactions are wired in CandleClashProgram.';
      });
    } catch (error) {
      setState(() => status = '$error');
    } finally {
      setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        actions: [
          IconButton(
            onPressed: () => Navigator.pushNamed(context, '/leaderboard'),
            icon: const Icon(Icons.leaderboard),
          ),
          IconButton(
            onPressed: () => Navigator.pushNamed(context, '/wallet'),
            icon: const Icon(Icons.account_balance_wallet),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Wallet', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          Text(address == null ? 'Not connected' : _short(address!)),
          Text('SOL wallet balance: ${walletSol.toStringAsFixed(4)}'),
          Text('Internal game balance: ${_sol(vault.balanceLamports)} SOL'),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: busy ? null : connect,
            icon: const Icon(Icons.link),
            label: Text(address == null ? 'Connect wallet' : 'Refresh wallet'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: address == null ? null : () => _comingSoon('Deposit'),
                  child: const Text('Deposit'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: address == null ? null : () => _comingSoon('Withdraw'),
                  child: const Text('Withdraw'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: address == null ? null : () => _comingSoon('Start Session'),
            child: const Text('Start Session'),
          ),
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: address == null ? null : () => Navigator.pushNamed(context, '/game'),
            child: const Text('Play'),
          ),
          const SizedBox(height: 24),
          Text('Profile', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text('Games ${profile.totalGames} | Wins ${profile.totalWins} | Losses ${profile.totalLosses}'),
          Text('EXP ${profile.exp} | Level ${profile.level} | Streak ${profile.currentStreak}'),
          const SizedBox(height: 24),
          Text(status),
        ],
      ),
    );
  }

  void _comingSoon(String action) {
    setState(() => status = '$action transaction builder is ready to wire to the generated Anchor IDL.');
  }

  String _short(String value) => '${value.substring(0, 4)}...${value.substring(value.length - 4)}';

  String _sol(int lamports) => (lamports / AppConstants.lamportsPerSol).toStringAsFixed(4);
}
