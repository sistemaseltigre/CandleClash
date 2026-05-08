import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class PoolDisplayComponent extends TextComponent {
  PoolDisplayComponent()
      : super(
          text: 'Daily Pool: -- SOL',
          textRenderer: TextPaint(
            style: const TextStyle(color: Color(0xffcfd8dc), fontSize: 16),
          ),
        );

  @override
  Future<void> onLoad() async {
    position = Vector2(20, 64);
  }
}
