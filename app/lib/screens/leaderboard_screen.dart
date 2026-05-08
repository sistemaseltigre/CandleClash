import 'package:flutter/material.dart';

import '../blockchain/candle_clash_program.dart';
import '../config/constants.dart';
import '../models/daily_player.dart';
import '../models/daily_pool.dart';
import 'widgets/clash_widgets.dart';

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
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                const ClashLogo(height: 58),
                const Spacer(),
                IconButton(onPressed: load, icon: const Icon(Icons.refresh)),
              ],
            ),
            const SizedBox(height: 16),
            ClashPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('LEADERBOARD', style: TextStyle(color: clashGreen, fontWeight: FontWeight.w900, letterSpacing: 1.4)),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      NeonStat(icon: Icons.calendar_today, label: 'UTC Day', value: '${program.currentUtcDayId()}', color: clashGreen),
                      const SizedBox(width: 10),
                      NeonStat(icon: Icons.emoji_events, label: 'Pool', value: _sol(currentPool?.totalPoolLamports ?? 0), color: clashYellow),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (players.isEmpty)
                    const _EmptyBoard()
                  else
                    for (var i = 0; i < players.length; i++)
                      _LeaderboardRow(rank: i + 1, player: players[i]),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const ClashBottomNav(current: 'leaderboard'),
    );
  }

  String _sol(int lamports) => (lamports / AppConstants.lamportsPerSol).toStringAsFixed(3);
}

class _EmptyBoard extends StatelessWidget {
  const _EmptyBoard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xff09111a),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: clashBorder),
      ),
      child: const Text(
        'No DailyPlayer accounts loaded yet. The next step is wiring account decoding through the generated Anchor IDL.',
        style: TextStyle(color: Colors.white70),
      ),
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({required this.rank, required this.player});

  final int rank;
  final DailyPlayer player;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: rank <= 3 ? clashGreen.withValues(alpha: 0.12) : const Color(0xff09111a),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: rank <= 3 ? clashGreen.withValues(alpha: 0.45) : clashBorder),
      ),
      child: Row(
        children: [
          SizedBox(width: 32, child: Text('#$rank', style: const TextStyle(color: clashYellow))),
          Expanded(child: Text(_short(player.player))),
          Text('${player.dailyScore}', style: const TextStyle(color: clashGreen, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  String _short(String value) => value.length < 8 ? value : '${value.substring(0, 4)}...${value.substring(value.length - 4)}';
}
