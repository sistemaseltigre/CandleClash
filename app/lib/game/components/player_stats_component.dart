import 'package:flutter/material.dart';

import '../../models/player_profile.dart';

class PlayerStatsComponent extends StatelessWidget {
  const PlayerStatsComponent({super.key, required this.profile});

  final PlayerProfile profile;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _Stat(label: 'Games', value: '${profile.totalGames}'),
        _Stat(label: 'Wins', value: '${profile.totalWins}'),
        _Stat(label: 'EXP', value: '${profile.exp}'),
        _Stat(label: 'Level', value: '${profile.level}'),
        _Stat(label: 'Streak', value: '${profile.currentStreak}'),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xff1b2227),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('$label $value'),
    );
  }
}
