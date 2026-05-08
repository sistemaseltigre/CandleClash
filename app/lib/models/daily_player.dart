class DailyPlayer {
  const DailyPlayer({
    required this.player,
    required this.dailyScore,
    required this.dailyGames,
    required this.dailyWins,
    required this.dailyLosses,
  });

  final String player;
  final int dailyScore;
  final int dailyGames;
  final int dailyWins;
  final int dailyLosses;
}
