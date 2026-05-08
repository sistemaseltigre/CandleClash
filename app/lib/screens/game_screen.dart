import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../blockchain/titan_price_service.dart';
import '../config/constants.dart';
import '../game/candle_clash_game.dart';
import '../game/components/long_short_buttons.dart';
import '../models/game_round.dart';
import 'widgets/clash_widgets.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final CandleClashGame game;
  final priceService = TitanPriceService();
  Timer? timer;
  double? visualPrice;
  String result = 'Choose UP or DOWN.';
  bool roundActive = false;
  int nextRoundId = 10294;
  double progress = 1;

  @override
  void initState() {
    super.initState();
    game = CandleClashGame(roundSeconds: AppConstants.defaultRoundDurationSeconds);
    timer = Timer.periodic(const Duration(seconds: 2), (_) => refreshPrice());
    refreshPrice();
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

  void startLocalRound(RoundDirection direction) {
    setState(() {
      roundActive = true;
      progress = 1;
      result = 'ROUND #$nextRoundId ${direction.name.toUpperCase()}';
      nextRoundId++;
    });
    game.resetRound();

    var elapsed = 0;
    Timer.periodic(const Duration(seconds: 1), (tick) {
      if (!mounted || !roundActive) {
        tick.cancel();
        return;
      }
      elapsed++;
      setState(() => progress = 1 - (elapsed / AppConstants.defaultRoundDurationSeconds));
      if (elapsed >= AppConstants.defaultRoundDurationSeconds) {
        tick.cancel();
        setState(() {
          roundActive = false;
          result = 'Timer finished. Send settle_round for official Pyth result.';
        });
      }
    });
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
                            Text('ROUND #$nextRoundId', style: const TextStyle(color: clashGreen, fontWeight: FontWeight.w800)),
                            const Spacer(),
                            const Text('Prize Pool  -- SOL', style: TextStyle(color: clashYellow)),
                          ],
                        ),
                        const Divider(height: 28, color: clashBorder),
                        const Text('WILL THE NEXT CANDLE', style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1.2)),
                        const SizedBox(height: 4),
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('RISE', style: TextStyle(color: clashGreen, fontSize: 34, fontWeight: FontWeight.w900)),
                            SizedBox(width: 8),
                            Text('OR', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                            SizedBox(width: 8),
                            Text('FALL?', style: TextStyle(color: clashRed, fontSize: 34, fontWeight: FontWeight.w900)),
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
                        const Text('TIME LEFT', style: TextStyle(color: Colors.white70, letterSpacing: 1.4)),
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
                          onLong: () => startLocalRound(RoundDirection.long),
                          onShort: () => startLocalRound(RoundDirection.short),
                        ),
                        const SizedBox(height: 14),
                        _InfoStrip(result: result),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: const [
                      NeonStat(icon: Icons.bolt, label: 'Entry Fee', value: '0.01', color: clashPurple),
                      SizedBox(width: 10),
                      NeonStat(icon: Icons.verified_user, label: 'Onchain', value: 'Pyth', color: clashGreen),
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
  const _InfoStrip({required this.result});

  final String result;

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
        style: const TextStyle(color: Colors.white70),
      ),
    );
  }
}
