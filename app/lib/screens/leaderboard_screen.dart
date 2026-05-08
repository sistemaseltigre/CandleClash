import 'package:flutter/material.dart';

import '../blockchain/candle_clash_program.dart';
import '../config/constants.dart';
import '../models/daily_player.dart';
import '../models/daily_pool.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final program = CandleClashProgram();
  DailyPool? pool;
  List<DailyPlayer> players = const [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final fetchedPool = await program.fetchDailyPool();
    final fetchedPlayers = await program.fetchLeaderboard();
    fetchedPlayers.sort((a, b) => b.dailyScore.compareTo(a.dailyScore));
    setState(() {
      pool = fetchedPool;
      players = fetchedPlayers;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentPool = pool;
    return Scaffold(
      appBar: AppBar(title: const Text('Leaderboard')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('UTC day_id: ${program.currentUtcDayId()}'),
          Text('Daily pool: ${_sol(currentPool?.totalPoolLamports ?? 0)} SOL'),
          const SizedBox(height: 12),
          if (players.isEmpty)
            const Text('No DailyPlayer accounts loaded yet. Query getProgramAccounts after IDL decoding is wired.'),
          for (final player in players)
            ListTile(
              title: Text(_short(player.player)),
              subtitle: Text('W ${player.dailyWins} L ${player.dailyLosses} G ${player.dailyGames}'),
              trailing: Text('${player.dailyScore} pts'),
            ),
        ],
      ),
    );
  }

  String _sol(int lamports) => (lamports / AppConstants.lamportsPerSol).toStringAsFixed(4);

  String _short(String value) => value.length < 8 ? value : '${value.substring(0, 4)}...${value.substring(value.length - 4)}';
}
