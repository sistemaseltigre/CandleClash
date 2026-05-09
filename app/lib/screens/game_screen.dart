import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../blockchain/titan_price_service.dart';
import '../config/constants.dart';
import '../game/candle_clash_game.dart';
import '../game/components/long_short_buttons.dart';
import '../models/game_round.dart';
import '../services/app_logger.dart';
import '../services/app_session.dart';
import 'widgets/clash_widgets.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final CandleClashGame game;
  final session = AppSession.instance;
  final priceService = TitanPriceService();
  Timer? timer;
  double? visualPrice;
  String result =
      'Choose UP or DOWN. First play will open wallet to fund the session.';
  Color resultColor = Colors.white70;
  GameRound? lastRound;
  bool roundActive = false;
  int nextRoundId = 10294;
  double progress = 1;
  int poolLamports = 0;

  @override
  void initState() {
    super.initState();
    game = CandleClashGame(
      roundSeconds: AppConstants.defaultRoundDurationSeconds,
    );
    timer = Timer.periodic(const Duration(seconds: 2), (_) => refreshPrice());
    refreshPrice();
    refreshGameState();
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> refreshPrice() async {
    final price = await priceService.fetchVisualSolPrice();
    if (!mounted || price == null) return;
    setState(() => visualPrice = price);
    game.visualPrice = price;
  }

  Future<void> refreshPool() async {
    final pool = await session.program.fetchDailyPool();
    if (!mounted) return;
    setState(() => poolLamports = pool.totalPoolLamports);
  }

  Future<void> refreshGameState() async {
    await session.refresh();
    unawaited(refreshPool());
    if (!mounted) return;
    setState(() => nextRoundId = session.profile.totalGames + 1);
  }

  Future<void> startRound(RoundDirection direction) async {
    if (roundActive) return;
    setState(() {
      roundActive = true;
      progress = 1;
      result = 'Preparing session...';
      resultColor = Colors.white70;
      lastRound = null;
    });

    try {
      await session.ensureReadyForGame();
      final connection = session.connection;
      final authority = session.sessionAuthority;
      if (connection == null || authority == null) {
        throw StateError('Wallet/session is not ready.');
      }
      final roundId = session.profile.totalGames + 1;

      setState(() => result = 'Sending start_round...');
      final startSig = await session.program.sendStartRound(
        playerAddress: connection.address,
        sessionAuthority: authority,
        roundId: roundId,
        direction: direction,
      );
      await AppLogger.info(
        'start_round sig=$startSig round=$roundId direction=${direction.name}',
      );

      setState(() {
        result = 'ROUND #$roundId ${direction.name.toUpperCase()}';
        nextRoundId = roundId + 1;
      });
      game.resetRound();

      var elapsed = 0;
      Timer.periodic(const Duration(seconds: 1), (tick) async {
        if (!mounted || !roundActive) {
          tick.cancel();
          return;
        }
        elapsed++;
        setState(
          () => progress =
              1 - (elapsed / AppConstants.defaultRoundDurationSeconds),
        );
        if (elapsed < AppConstants.defaultRoundDurationSeconds) return;
        tick.cancel();
        setState(() {
          result = 'Settling round...';
        });
        try {
          final settleSig = await session.program.sendSettleRound(
            playerAddress: connection.address,
            sessionAuthority: authority,
            roundId: roundId,
          );
          await AppLogger.info('settle_round sig=$settleSig round=$roundId');
          final round = await session.program.fetchRound(
            playerAddress: connection.address,
            roundId: roundId,
          );
          unawaited(
            session.refresh().then((_) {
              if (!mounted) return;
              setState(() => nextRoundId = session.profile.totalGames + 1);
            }),
          );
          unawaited(refreshPool());
          if (!mounted) return;
          setState(() {
            roundActive = false;
            if (round == null) {
              result =
                  'Round settled. Vault ${_sol(session.vault.balanceLamports)} SOL';
              resultColor = Colors.white70;
            } else {
              final pushed = _isPush(round);
              resultColor = pushed
                  ? clashYellow
                  : round.won
                  ? clashGreen
                  : clashRed;
              lastRound = round;
              result = pushed
                  ? 'PUSH'
                  : round.won
                  ? 'WIN'
                  : 'LOSS';
              if (pushed) {
                HapticFeedback.selectionClick();
              } else if (round.won) {
                HapticFeedback.heavyImpact();
              } else {
                HapticFeedback.mediumImpact();
              }
            }
          });
        } catch (error, stack) {
          await AppLogger.error('settle_round failed', error, stack);
          if (!mounted) return;
          setState(() {
            roundActive = false;
            result = 'Settle failed. Check candle_clash.log: $error';
            resultColor = clashRed;
          });
        }
      });
    } catch (error, stack) {
      await AppLogger.error('startRound failed', error, stack);
      if (!mounted) return;
      setState(() {
        roundActive = false;
        result = 'Round failed. Check candle_clash.log: $error';
        resultColor = clashRed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  const ClashLogo(height: 58),
                  const Spacer(),
                  _PricePill(price: visualPrice),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  ClashPanel(
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Text(
                              'ROUND #$nextRoundId',
                              style: const TextStyle(
                                color: clashGreen,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              'Prize Pool  ${_sol(poolLamports)} SOL',
                              style: const TextStyle(color: clashYellow),
                            ),
                          ],
                        ),
                        const Divider(height: 28, color: clashBorder),
                        const Text(
                          'WILL THE NEXT CANDLE',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'RISE',
                              style: TextStyle(
                                color: clashGreen,
                                fontSize: 34,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'OR',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'FALL?',
                              style: TextStyle(
                                color: clashRed,
                                fontSize: 34,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(
                          height: 280,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: GameWidget(game: game),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'TIME LEFT',
                          style: TextStyle(
                            color: Colors.white70,
                            letterSpacing: 1.4,
                          ),
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: progress.clamp(0, 1),
                          color: roundActive ? clashRed : clashGreen,
                          backgroundColor: Colors.white12,
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        const SizedBox(height: 18),
                        LongShortButtons(
                          enabled: !roundActive,
                          onLong: () => startRound(RoundDirection.long),
                          onShort: () => startRound(RoundDirection.short),
                        ),
                        const SizedBox(height: 14),
                        if (lastRound == null)
                          _InfoStrip(result: result, color: resultColor)
                        else
                          _ResultBanner(round: lastRound!),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const NeonStat(
                        icon: Icons.bolt,
                        label: 'Entry Fee',
                        value: '0.00002',
                        color: clashPurple,
                      ),
                      const SizedBox(width: 10),
                      NeonStat(
                        icon: Icons.account_balance_wallet,
                        label: 'Vault',
                        value: _sol(session.vault.balanceLamports),
                        color: clashYellow,
                      ),
                      const SizedBox(width: 10),
                      const NeonStat(
                        icon: Icons.verified_user,
                        label: 'Onchain',
                        value: 'Oracle',
                        color: clashGreen,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const ClashBottomNav(current: 'game'),
    );
  }
}

String _sol(int lamports) =>
    (lamports / AppConstants.lamportsPerSol).toStringAsFixed(4);

bool _isPush(GameRound round) =>
    round.scoreDelta == 0 && round.startPrice == round.endPrice;

class _PricePill extends StatelessWidget {
  const _PricePill({required this.price});

  final double? price;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xff0b121b),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: clashBorder),
      ),
      child: Text('SOL/USD ${price?.toStringAsFixed(2) ?? '--'}'),
    );
  }
}

class _InfoStrip extends StatelessWidget {
  const _InfoStrip({required this.result, this.color = Colors.white70});

  final String result;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xff09111a),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: clashBorder),
      ),
      child: Text(
        result,
        textAlign: TextAlign.center,
        style: TextStyle(color: color, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _ResultBanner extends StatelessWidget {
  const _ResultBanner({required this.round});

  final GameRound round;

  @override
  Widget build(BuildContext context) {
    final pushed = _isPush(round);
    final color = pushed
        ? clashYellow
        : round.won
        ? clashGreen
        : clashRed;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.75), width: 1.4),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.20),
            blurRadius: 24,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            pushed
                ? 'PUSH'
                : round.won
                ? 'WIN'
                : 'LOSS',
            style: TextStyle(
              color: color,
              fontSize: 34,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ResultPill(label: 'Points', value: '+${round.scoreDelta}'),
              const SizedBox(width: 8),
              _ResultPill(label: 'EXP', value: '+${round.expDelta}'),
              const SizedBox(width: 8),
              _ResultPill(
                label: 'Move',
                value:
                    '${round.startPrice.toStringAsFixed(2)} -> ${round.endPrice.toStringAsFixed(2)}',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ResultPill extends StatelessWidget {
  const _ResultPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xff071018),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: clashBorder),
        ),
        child: Column(
          children: [
            Text(
              label.toUpperCase(),
              style: const TextStyle(color: Colors.white54, fontSize: 9),
            ),
            const SizedBox(height: 2),
            FittedBox(
              child: Text(
                value,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
