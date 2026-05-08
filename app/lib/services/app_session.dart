import 'package:solana/solana.dart';

import '../blockchain/candle_clash_program.dart';
import '../blockchain/solana_service.dart';
import '../blockchain/wallet_service.dart';
import '../config/constants.dart';
import '../models/player_profile.dart';
import '../models/player_vault.dart';
import 'app_logger.dart';

class AppSession {
  AppSession._();

  static final instance = AppSession._();

  final wallet = WalletService();
  final solana = SolanaService();
  final program = CandleClashProgram();

  WalletConnection? connection;
  Ed25519HDKeyPair? sessionAuthority;
  bool sessionReady = false;
  PlayerVault vault = PlayerVault.empty;
  PlayerProfile profile = PlayerProfile.empty;
  double walletSol = 0;

  bool get isConnected => connection != null;

  Future<WalletConnection?> connect() async {
    connection = await wallet.connect();
    await refresh();
    return connection;
  }

  Future<void> refresh() async {
    final address = connection?.address;
    if (address == null) return;
    walletSol = await solana.getSolBalance(address);
    vault = await program.fetchVault(address);
    profile = await program.fetchProfile(address);
  }

  Future<void> ensureReadyForGame() async {
    final activeConnection = connection ?? await connect();
    if (activeConnection == null) {
      throw StateError('Wallet is not connected.');
    }

    sessionAuthority ??= await program.createSessionAuthority();
    final authority = sessionAuthority!;
    if (sessionReady &&
        vault.balanceLamports >= AppConstants.defaultEntryFeeLamports) {
      return;
    }
    final needsDeposit =
        vault.balanceLamports < AppConstants.defaultEntryFeeLamports;

    await AppLogger.info(
      'ensureReadyForGame wallet=${activeConnection.address} needsDeposit=$needsDeposit vault=${vault.balanceLamports}',
    );

    final tx = await program.buildSetupTransaction(
      playerAddress: activeConnection.address,
      sessionAuthority: authority.publicKey,
      depositLamports: needsDeposit ? AppConstants.defaultDepositLamports : 0,
      maxSpendLamports: AppConstants.defaultDepositLamports,
      sessionFundingLamports: AppConstants.defaultSessionFundingLamports,
    );
    await AppLogger.info('setup tx built bytes=${tx.length}');

    final signature = await wallet.signAndSendTransactionWithFallback(
      transaction: tx,
      rpc: program.rpc,
    );
    if (signature == null) {
      throw StateError('Wallet did not return a setup signature.');
    }
    await AppLogger.info('setup tx sent signature=$signature');
    await Future<void>.delayed(const Duration(seconds: 2));
    await refresh();
    sessionReady = true;
  }
}
