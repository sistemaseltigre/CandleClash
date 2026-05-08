class DailyPool {
  const DailyPool({
    required this.dayId,
    required this.totalPoolLamports,
    required this.totalGames,
    required this.totalPlayers,
  });

  final int dayId;
  final int totalPoolLamports;
  final int totalGames;
  final int totalPlayers;
}
