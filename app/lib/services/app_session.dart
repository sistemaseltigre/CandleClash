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
  int sessionAuthorityLamports = 0;

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
    final authority = sessionAuthority;
    if (authority != null) {
      sessionAuthorityLamports = await solana.getLamportBalance(
        authority.publicKey.toBase58(),
      );
    }
  }

  Future<void> ensureReadyForGame() async {
    final activeConnection = connection ?? await connect();
    if (activeConnection == null) {
      throw StateError('Wallet is not connected.');
    }

    sessionAuthority ??= await program.createSessionAuthority();
    final authority = sessionAuthority!;
    await refresh();
    if (sessionReady &&
        vault.balanceLamports >= AppConstants.defaultEntryFeeLamports &&
        sessionAuthorityLamports >= AppConstants.minSessionAuthorityLamports) {
      return;
    }
    final needsDeposit =
        vault.balanceLamports < AppConstants.defaultEntryFeeLamports;
    final depositLamports = needsDeposit
        ? AppConstants.defaultDepositLamports
        : 0;
    final anticipatedVaultLamports = vault.balanceLamports + depositLamports;
    final maxSpendLamports = anticipatedVaultLamports
        .clamp(
          AppConstants.defaultEntryFeeLamports,
          AppConstants.defaultDepositLamports,
        )
        .toInt();
    final needsSessionFunding =
        sessionAuthorityLamports < AppConstants.minSessionAuthorityLamports;
    final sessionFundingLamports = needsSessionFunding
        ? AppConstants.defaultSessionFundingLamports
        : 0;

    await AppLogger.info(
      'ensureReadyForGame wallet=${activeConnection.address} needsDeposit=$needsDeposit vault=${vault.balanceLamports} authorityLamports=$sessionAuthorityLamports needsSessionFunding=$needsSessionFunding',
    );

    final tx = await program.buildSetupTransaction(
      playerAddress: activeConnection.address,
      sessionAuthority: authority.publicKey,
      depositLamports: depositLamports,
      maxSpendLamports: maxSpendLamports,
      sessionFundingLamports: sessionFundingLamports,
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

  Future<String> deposit(int lamports) async {
    final activeConnection = connection ?? await connect();
    if (activeConnection == null) {
      throw StateError('Wallet is not connected.');
    }
    final tx = await program.buildDepositTransaction(
      playerAddress: activeConnection.address,
      lamports: lamports,
    );
    final signature = await wallet.signAndSendTransactionWithFallback(
      transaction: tx,
      rpc: program.rpc,
    );
    if (signature == null) {
      throw StateError('Wallet did not return a deposit signature.');
    }
    await AppLogger.info(
      'deposit sent signature=$signature lamports=$lamports',
    );
    await Future<void>.delayed(const Duration(seconds: 2));
    await refresh();
    return signature;
  }

  Future<String> withdraw(int lamports) async {
    final activeConnection = connection;
    if (activeConnection == null) {
      throw StateError('Wallet is not connected.');
    }
    final amount = lamports.clamp(0, vault.balanceLamports).toInt();
    if (amount == 0) {
      throw StateError('No internal balance available to withdraw.');
    }
    final tx = await program.buildWithdrawTransaction(
      playerAddress: activeConnection.address,
      lamports: amount,
    );
    final signature = await wallet.signAndSendTransactionWithFallback(
      transaction: tx,
      rpc: program.rpc,
    );
    if (signature == null) {
      throw StateError('Wallet did not return a withdraw signature.');
    }
    await AppLogger.info('withdraw sent signature=$signature lamports=$amount');
    await Future<void>.delayed(const Duration(seconds: 2));
    await refresh();
    return signature;
  }
}
