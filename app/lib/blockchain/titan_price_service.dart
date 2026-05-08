import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/constants.dart';

class TitanPriceService {
  Future<double?> fetchVisualSolPrice() async {
    final response = await http.get(Uri.parse(AppConstants.titanPriceUrl));
    if (response.statusCode != 200) return null;
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final data = json['data'] as Map<String, dynamic>?;
    final sol = data?['SOL'] as Map<String, dynamic>?;
    final price = sol?['price'];
    if (price is num) return price.toDouble();
    if (price is String) return double.tryParse(price);
    return null;
  }
}
