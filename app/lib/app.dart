import 'package:flutter/material.dart';

import 'screens/game_screen.dart';
import 'screens/home_screen.dart';
import 'screens/leaderboard_screen.dart';
import 'screens/wallet_screen.dart';

class CandleClashApp extends StatelessWidget {
  const CandleClashApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Candle Clash',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff00c2a8),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xff101417),
        useMaterial3: true,
      ),
      routes: {
        '/': (_) => const HomeScreen(),
        '/game': (_) => const GameScreen(),
        '/leaderboard': (_) => const LeaderboardScreen(),
        '/wallet': (_) => const WalletScreen(),
      },
    );
  }
}
