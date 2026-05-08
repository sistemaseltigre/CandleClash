import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class CandleChartComponent extends PositionComponent with HasGameReference {
  final List<double> _prices = [150, 150.1, 149.9, 150.2, 150.05];

  @override
  Future<void> onLoad() async {
    position = Vector2(14, 82);
    size = Vector2(game.size.x - 28, game.size.y * 0.48);
  }

  void updatePrice(double price) {
    if (_prices.length > 80) _prices.removeAt(0);
    _prices.add(price);
  }

  void reset() {
    final last = _prices.isEmpty ? 150.0 : _prices.last;
    _prices
      ..clear()
      ..add(last);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final paint = Paint()
      ..color = const Color(0xff2a343a)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final upPaint = Paint()
      ..color = const Color(0xff00d18f)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final downPaint = Paint()
      ..color = const Color(0xffff4d67)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Offset.zero & size.toSize(),
        const Radius.circular(8),
      ),
      paint,
    );

    if (_prices.length < 2) return;
    final minPrice = _prices.reduce(min);
    final maxPrice = _prices.reduce(max);
    final center = (minPrice + maxPrice) / 2;
    final range = max(0.7, maxPrice - minPrice);
    final low = center - (range / 2);
    final step = size.x / max(1, _prices.length - 1);

    for (var i = 1; i < _prices.length; i++) {
      final previous = _point(i - 1, step, low, range);
      final current = _point(i, step, low, range);
      canvas.drawLine(
        previous,
        current,
        _prices[i] >= _prices[i - 1] ? upPaint : downPaint,
      );
    }
  }

  Offset _point(int index, double step, double minPrice, double range) {
    final x = index * step;
    final y =
        size.y - ((_prices[index] - minPrice) / range * (size.y - 42)) - 21;
    return Offset(x, y);
  }
}
