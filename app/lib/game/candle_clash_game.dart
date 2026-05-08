import 'dart:math';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'components/candle_chart_component.dart';
import 'components/pool_display_component.dart';
import 'components/timer_component.dart';

class CandleClashGame extends FlameGame {
  CandleClashGame({required this.roundSeconds});

  final int roundSeconds;
  late final CandleChartComponent chart;
  late final ClashTimerComponent timer;
  double visualPrice = 150;

  @override
  Color backgroundColor() => const Color(0xff101417);

  @override
  Future<void> onLoad() async {
    chart = CandleChartComponent();
    timer = ClashTimerComponent(totalSeconds: roundSeconds);
    add(chart);
    add(timer);
    add(PoolDisplayComponent());
  }

  @override
  void update(double dt) {
    super.update(dt);
    visualPrice += sin(DateTime.now().millisecondsSinceEpoch / 700) * 0.002;
    chart.updatePrice(visualPrice);
  }

  void resetRound() {
    timer.reset();
    chart.reset();
  }
}
