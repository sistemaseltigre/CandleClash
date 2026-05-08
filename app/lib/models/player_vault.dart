class PlayerVault {
  const PlayerVault({
    required this.player,
    required this.balanceLamports,
    required this.totalDepositedLamports,
    required this.totalWithdrawnLamports,
  });

  final String player;
  final int balanceLamports;
  final int totalDepositedLamports;
  final int totalWithdrawnLamports;

  static const empty = PlayerVault(
    player: '',
    balanceLamports: 0,
    totalDepositedLamports: 0,
    totalWithdrawnLamports: 0,
  );
}
