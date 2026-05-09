class AppConstants {
  const AppConstants._();

  static const appName = 'Candle Clash';
  static const lamportsPerSol = 1000000000;
  static const defaultEntryFeeLamports = 20000;
  static const defaultPoolFeeLamports = 15000;
  static const defaultTreasuryFeeLamports = 5000;
  static const defaultRoundDurationSeconds = 5;
  static const defaultDepositLamports = 1000000;
  static const defaultSessionFundingLamports = 10000000;
  static const minSessionAuthorityLamports = 5000000;

  // Replace after `anchor deploy --provider.cluster devnet`.
  static const candleClashProgramId =
      'E5bjWeyYLChSt2RMZUH3f9QVyCvU9z1sBRyhRB4jTgL3';

  static const pythSolUsdDevnetPriceAccount =
      '7UVimffxr9ow1uXYxsr4LHAcV58mLzhmwaeKvJ1pjLiE';
  static const pythSolUsdFeedId =
      'ef0d8b6fda2ceba41da15d4095d1da392a0d2f8ed0c6c7bc0f4cfac8c280b56d';

  static const pythHermesLatestPriceUrl =
      'https://hermes.pyth.network/v2/updates/price/latest?parsed=true&ids[]=0x$pythSolUsdFeedId';
}
