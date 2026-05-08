import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class CandleChartComponent extends PositionComponent with HasGameReference {
  final List<double> _prices = [150, 150.1, 149.9, 150.2, 150.05];

  @override
  Future<void> onLoad() async {
    position = Vector2(20, 88);
    size = Vector2(game.size.x - 40, game.size.y * 0.42);
  }

  void updatePrice(double price) {
    if (_prices.length > 48) _prices.removeAt(0);
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
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    final downPaint = Paint()
      ..color = const Color(0xffff4d67)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size.toSize(), const Radius.circular(8)),
      paint,
    );

    if (_prices.length < 2) return;
    final minPrice = _prices.reduce(min);
    final maxPrice = _prices.reduce(max);
    final range = max(0.001, maxPrice - minPrice);
    final step = size.x / max(1, _prices.length - 1);

    for (var i = 1; i < _prices.length; i++) {
      final previous = _point(i - 1, step, minPrice, range);
      final current = _point(i, step, minPrice, range);
      canvas.drawLine(
        previous,
        current,
        _prices[i] >= _prices[i - 1] ? upPaint : downPaint,
      );
    }
  }

  Offset _point(int index, double step, double minPrice, double range) {
    final x = index * step;
    final y = size.y - ((_prices[index] - minPrice) / range * (size.y - 24)) - 12;
    return Offset(x, y);
  }
}
