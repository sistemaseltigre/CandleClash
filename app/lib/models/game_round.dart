enum RoundDirection { long, short }

class GameRound {
  const GameRound({
    required this.roundId,
    required this.direction,
    required this.startPrice,
    required this.endPrice,
    required this.settled,
    required this.won,
    required this.scoreDelta,
    required this.expDelta,
    required this.entryFeeLamports,
  });

  final int roundId;
  final RoundDirection direction;
  final double startPrice;
  final double endPrice;
  final bool settled;
  final bool won;
  final int scoreDelta;
  final int expDelta;
  final int entryFeeLamports;
}
