import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/constants.dart';

class TitanPriceService {
  Future<double?> fetchVisualSolPrice() async {
    final response = await http.get(
      Uri.parse(AppConstants.pythHermesLatestPriceUrl),
    );
    if (response.statusCode != 200) return null;
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final parsed = json['parsed'] as List<dynamic>?;
    if (parsed == null || parsed.isEmpty) return null;
    final feed = parsed.first as Map<String, dynamic>;
    final priceData = feed['price'] as Map<String, dynamic>?;
    final priceText = priceData?['price'];
    final exponent = priceData?['expo'];
    final rawPrice = priceText is String
        ? double.tryParse(priceText)
        : priceText is num
        ? priceText.toDouble()
        : null;
    if (rawPrice == null || exponent is! num) return null;
    return rawPrice * _pow10(exponent.toInt());
  }

  double _pow10(int exponent) {
    var value = 1.0;
    if (exponent >= 0) {
      for (var i = 0; i < exponent; i++) {
        value *= 10;
      }
    } else {
      for (var i = 0; i < -exponent; i++) {
        value /= 10;
      }
    }
    return value;
  }
}
