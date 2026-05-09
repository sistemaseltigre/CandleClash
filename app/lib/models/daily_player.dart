class DailyPlayer {
  const DailyPlayer({
    required this.dayId,
    required this.player,
    required this.dailyScore,
    required this.dailyGames,
    required this.dailyWins,
    required this.dailyLosses,
    required this.dailyLong,
    required this.dailyShort,
    required this.dailySpentLamports,
    required this.dailyPoolContributedLamports,
  });

  final int dayId;
  final String player;
  final int dailyScore;
  final int dailyGames;
  final int dailyWins;
  final int dailyLosses;
  final int dailyLong;
  final int dailyShort;
  final int dailySpentLamports;
  final int dailyPoolContributedLamports;
}
