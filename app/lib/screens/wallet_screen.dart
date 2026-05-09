import 'package:flutter/material.dart';

import '../config/constants.dart';
import '../services/app_logger.dart';
import '../services/app_session.dart';
import 'widgets/clash_widgets.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final session = AppSession.instance;
  bool busy = false;
  String status = 'Ready';

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    if (!session.isConnected) return;
    await session.refresh();
    if (mounted) setState(() {});
  }

  Future<void> deposit() async {
    setState(() {
      busy = true;
      status = 'Opening wallet for deposit...';
    });
    try {
      final sig = await session.deposit(AppConstants.defaultDepositLamports);
      setState(() => status = 'Deposit sent ${_short(sig)}');
    } catch (error, stack) {
      await AppLogger.error('wallet screen deposit failed', error, stack);
      setState(() => status = 'Deposit failed: $error');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> withdraw() async {
    setState(() {
      busy = true;
      status = 'Opening wallet for withdraw...';
    });
    try {
      final sig = await session.withdraw(session.vault.balanceLamports);
      setState(() => status = 'Withdraw sent ${_short(sig)}');
    } catch (error, stack) {
      await AppLogger.error('wallet screen withdraw failed', error, stack);
      setState(() => status = 'Withdraw failed: $error');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vaultSol = _sol(session.vault.balanceLamports);
    final walletSol = session.walletSol.toStringAsFixed(5);
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: refresh,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Row(
                children: [
                  ClashLogo(height: 58),
                  Spacer(),
                  Icon(Icons.account_balance_wallet, color: clashGreen),
                ],
              ),
              const SizedBox(height: 16),
              ClashPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'WALLET',
                      style: TextStyle(
                        color: clashGreen,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Center(
                      child: Column(
                        children: [
                          const Icon(Icons.token, size: 48, color: clashPurple),
                          const SizedBox(height: 8),
                          const Text(
                            'INTERNAL GAME BALANCE',
                            style: TextStyle(
                              color: Colors.white54,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$vaultSol SOL',
                            style: const TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Wallet: $walletSol SOL',
                            style: const TextStyle(color: Colors.white54),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton(
                            onPressed: busy ? null : deposit,
                            style: FilledButton.styleFrom(
                              backgroundColor: clashGreen,
                              foregroundColor: Colors.black,
                            ),
                            child: const Text('DEPOSIT 0.001'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton(
                            onPressed:
                                busy || session.vault.balanceLamports == 0
                                ? null
                                : withdraw,
                            child: const Text('WITHDRAW ALL'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(status, style: const TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              ClashPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'STATS',
                      style: TextStyle(
                        color: Colors.white70,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text('Level ${session.profile.level}'),
                    Text('EXP ${session.profile.exp}'),
                    Text(
                      'Games ${session.profile.totalGames} | Wins ${session.profile.totalWins} | Losses ${session.profile.totalLosses}',
                    ),
                    Text(
                      'Current streak ${session.profile.currentStreak} | Best ${session.profile.bestStreak}',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              FutureBuilder(
                future: AppLogger.file(),
                builder: (context, snapshot) {
                  final path = snapshot.data?.path ?? 'loading...';
                  return ClashPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'DEBUG LOG',
                          style: TextStyle(
                            color: Colors.white70,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 10),
                        SelectableText(
                          path,
                          style: const TextStyle(
                            color: clashGreen,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const ClashBottomNav(current: 'wallet'),
    );
  }

  String _sol(int lamports) =>
      (lamports / AppConstants.lamportsPerSol).toStringAsFixed(6);

  String _short(String value) =>
      value.length < 14 ? value : '${value.substring(0, 6)}...';
}
