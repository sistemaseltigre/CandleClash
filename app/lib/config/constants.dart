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

  // Configure the official Pyth SOL/USD devnet price account here.
  // The Anchor MVP currently uses a mock-compatible price account for tests;
  // swap the program reader to Pyth before production settlement.
  static const pythSolUsdDevnetPriceAccount =
      'PUT_PYTH_SOL_USD_DEVNET_PRICE_ACCOUNT_HERE';

  // Optional: add Titan Exchange endpoint/key here for visual-only live price.
  static const titanPriceUrl = 'https://api.jup.ag/price/v2?ids=SOL';
}
