import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class ClashTimerComponent extends TextComponent {
  ClashTimerComponent({required this.totalSeconds})
    : super(
        text: '$totalSeconds',
        textRenderer: TextPaint(
          style: const TextStyle(
            color: Colors.white,
            fontSize: 30,
            fontWeight: FontWeight.w800,
          ),
        ),
      );

  final int totalSeconds;
  double _remaining = 0;

  @override
  Future<void> onLoad() async {
    position = Vector2(20, 28);
    reset();
  }

  @override
  void update(double dt) {
    super.update(dt);
    _remaining = (_remaining - dt).clamp(0, totalSeconds.toDouble());
    text = '${_remaining.ceil()}s';
  }

  void reset() {
    _remaining = totalSeconds.toDouble();
  }
}
