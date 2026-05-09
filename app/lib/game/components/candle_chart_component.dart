import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class CandleChartComponent extends PositionComponent with HasGameReference {
  final List<_Candle> _candles = [];
  DateTime _lastSampleAt = DateTime.fromMillisecondsSinceEpoch(0);
  double _lastPrice = 150;
  final _random = Random(7);

  @override
  Future<void> onLoad() async {
    position = Vector2(14, 78);
    size = Vector2(game.size.x - 28, game.size.y * 0.42);
    reset();
  }

  void updatePrice(double price) {
    _lastPrice = price;
    final now = DateTime.now();
    if (now.difference(_lastSampleAt).inMilliseconds < 360) return;
    _lastSampleAt = now;

    if (_candles.isEmpty) {
      _candles.add(_seedCandle(price));
      return;
    }

    final previous = _candles.last;
    final drift = (price - previous.close) * 0.75;
    final noise = (_random.nextDouble() - 0.48) * 0.12;
    final close = previous.close + drift + noise;
    final open = previous.close;
    final wick = 0.06 + _random.nextDouble() * 0.16;
    _candles.add(
      _Candle(
        open: open,
        high: max(open, close) + wick,
        low: min(open, close) - wick * (0.7 + _random.nextDouble() * 0.5),
        close: close,
      ),
    );
    if (_candles.length > 28) _candles.removeAt(0);
  }

  void reset() {
    _candles.clear();
    var price = _lastPrice;
    for (var i = 0; i < 18; i++) {
      final open = price;
      final close = open + (_random.nextDouble() - 0.52) * 0.42;
      final wick = 0.08 + _random.nextDouble() * 0.22;
      _candles.add(
        _Candle(
          open: open,
          close: close,
          high: max(open, close) + wick,
          low: min(open, close) - wick,
        ),
      );
      price = close;
    }
  }

  _Candle _seedCandle(double price) {
    final close = price + (_random.nextDouble() - 0.5) * 0.16;
    final wick = 0.08 + _random.nextDouble() * 0.16;
    return _Candle(
      open: price,
      close: close,
      high: max(price, close) + wick,
      low: min(price, close) - wick,
    );
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    _drawFrame(canvas);
    if (_candles.isEmpty) return;

    final minPrice = _candles.map((candle) => candle.low).reduce(min);
    final maxPrice = _candles.map((candle) => candle.high).reduce(max);
    final mid = (maxPrice + minPrice) / 2;
    final range = max(1.2, maxPrice - minPrice);
    final low = mid - range / 2;
    final chartHeight = size.y - 34;
    final candleSlot = size.x / (_candles.length + 1);
    final bodyWidth = min(18.0, candleSlot * 0.55);

    for (var i = 0; i < _candles.length; i++) {
      final candle = _candles[i];
      final x = candleSlot * (i + 1);
      final color = candle.close >= candle.open
          ? const Color(0xff00ff6a)
          : const Color(0xffff3b3b);
      final glowPaint = Paint()
        ..color = color.withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      final linePaint = Paint()
        ..color = color.withValues(alpha: 0.92)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      final bodyPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.98),
            color.withValues(alpha: 0.52),
          ],
        ).createShader(Rect.fromLTWH(x - bodyWidth / 2, 0, bodyWidth, size.y));

      final highY = _priceY(candle.high, low, range, chartHeight);
      final lowY = _priceY(candle.low, low, range, chartHeight);
      final openY = _priceY(candle.open, low, range, chartHeight);
      final closeY = _priceY(candle.close, low, range, chartHeight);
      final top = min(openY, closeY);
      final height = max(5.0, (openY - closeY).abs());
      final body = RRect.fromRectAndRadius(
        Rect.fromLTWH(x - bodyWidth / 2, top, bodyWidth, height),
        const Radius.circular(2),
      );

      canvas.drawLine(Offset(x, highY), Offset(x, lowY), linePaint);
      canvas.drawRRect(body.inflate(5), glowPaint);
      canvas.drawRRect(body, bodyPaint);
      canvas.drawRRect(
        body,
        Paint()
          ..color = color.withValues(alpha: 0.85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }

    _drawNextCandleSlot(canvas);
  }

  void _drawFrame(Canvas canvas) {
    final border = Paint()
      ..color = const Color(0xff26333b)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final grid = Paint()
      ..color = const Color(0xff1f2a31).withValues(alpha: 0.72)
      ..strokeWidth = 1;
    final bg = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xff071014), Color(0xff030709)],
      ).createShader(Offset.zero & size.toSize());

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Offset.zero & size.toSize(),
        const Radius.circular(8),
      ),
      bg,
    );
    for (var i = 1; i < 5; i++) {
      final y = size.y * i / 5;
      canvas.drawLine(Offset(0, y), Offset(size.x, y), grid);
    }
    for (var i = 1; i < 7; i++) {
      final x = size.x * i / 7;
      canvas.drawLine(Offset(x, 0), Offset(x, size.y), grid);
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Offset.zero & size.toSize(),
        const Radius.circular(8),
      ),
      border,
    );
  }

  void _drawNextCandleSlot(Canvas canvas) {
    final rect = Rect.fromLTWH(size.x - 42, 20, 30, size.y - 46);
    final paint = Paint()
      ..color = const Color(0xff00ff6a).withValues(alpha: 0.48)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      paint,
    );
    final textPainter = TextPainter(
      text: const TextSpan(
        text: '?',
        style: TextStyle(
          color: Colors.white,
          fontSize: 34,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(
        rect.center.dx - textPainter.width / 2,
        rect.center.dy - textPainter.height / 2,
      ),
    );
  }

  double _priceY(double price, double low, double range, double chartHeight) {
    return chartHeight - ((price - low) / range * (chartHeight - 24)) + 12;
  }
}

class _Candle {
  const _Candle({
    required this.open,
    required this.high,
    required this.low,
    required this.close,
  });

  final double open;
  final double high;
  final double low;
  final double close;
}
