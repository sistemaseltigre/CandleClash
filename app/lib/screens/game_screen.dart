import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../blockchain/titan_price_service.dart';
import '../config/constants.dart';
import '../game/candle_clash_game.dart';
import '../game/components/long_short_buttons.dart';
import '../models/game_round.dart';

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
  String result = 'Choose LONG or SHORT when ready.';
  bool roundActive = false;
  int nextRoundId = 1;

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
      result = 'Round $nextRoundId ${direction.name.toUpperCase()} started. Official settlement must be sent onchain.';
      nextRoundId++;
    });
    game.resetRound();
    Future.delayed(const Duration(seconds: AppConstants.defaultRoundDurationSeconds), () {
      if (!mounted) return;
      setState(() {
        roundActive = false;
        result = 'Timer finished. Call settle_round to read official Pyth price onchain.';
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Candle Clash')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Visual SOL/USD ${visualPrice?.toStringAsFixed(2) ?? '--'}'),
                const Text('Official: Pyth onchain'),
              ],
            ),
          ),
          Expanded(child: GameWidget(game: game)),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                LongShortButtons(
                  enabled: !roundActive,
                  onLong: () => startLocalRound(RoundDirection.long),
                  onShort: () => startLocalRound(RoundDirection.short),
                ),
                const SizedBox(height: 12),
                Text(result, textAlign: TextAlign.center),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
