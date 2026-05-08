class PlayerProfile {
  const PlayerProfile({
    required this.player,
    required this.totalGames,
    required this.totalWins,
    required this.totalLosses,
    required this.totalLong,
    required this.totalShort,
    required this.exp,
    required this.level,
    required this.currentStreak,
    required this.bestStreak,
  });

  final String player;
  final int totalGames;
  final int totalWins;
  final int totalLosses;
  final int totalLong;
  final int totalShort;
  final int exp;
  final int level;
  final int currentStreak;
  final int bestStreak;

  static const empty = PlayerProfile(
    player: '',
    totalGames: 0,
    totalWins: 0,
    totalLosses: 0,
    totalLong: 0,
    totalShort: 0,
    exp: 0,
    level: 1,
    currentStreak: 0,
    bestStreak: 0,
  );
}
