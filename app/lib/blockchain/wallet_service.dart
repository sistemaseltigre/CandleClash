import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:solana/base58.dart';
import 'package:solana/solana.dart';
import 'package:solana_mobile_client/solana_mobile_client.dart';

import '../config/rpc_config.dart';
import '../services/app_logger.dart';

class WalletConnection {
  const WalletConnection({
    required this.address,
    required this.authToken,
    required this.publicKeyBytes,
  });

  final String address;
  final String authToken;
  final Uint8List publicKeyBytes;
}

class WalletUtils {
  const WalletUtils._();

  static String shortAddress(String address) {
    if (address.length <= 10) return address;
    return '${address.substring(0, 4)}...${address.substring(address.length - 4)}';
  }
}

class WalletService {
  static final _identityUri = Uri.parse('https://candleclash.dev');
  static const _identityName = 'Candle Clash';
  static const _authorizeTimeout = Duration(seconds: 15);
  static const _associationSettleDelay = Duration(milliseconds: 700);
  static const _retryBackoff = Duration(milliseconds: 350);
  static const _maxConnectAttempts = 2;

  WalletConnection? _connection;

  WalletConnection? get connection => _connection;

  Future<bool> get isAvailable => LocalAssociationScenario.isAvailable();

  Future<WalletConnection?> connect() async {
    try {
      final endpointAvailable = await LocalAssociationScenario.isAvailable();
      await AppLogger.info('wallet connect isAvailable=$endpointAvailable');
      _debugLog('isAvailable=$endpointAvailable');
      if (!endpointAvailable) return null;

      Object? lastError;
      for (var attempt = 0; attempt < _maxConnectAttempts; attempt++) {
        try {
          return await _connectOnce();
        } on Exception catch (error) {
          lastError = error;
          _debugLog('connect attempt ${attempt + 1} failed: $error');
          if (_isUserRejected(error)) return null;
          if (attempt + 1 < _maxConnectAttempts &&
              _isTransientAssociationError(error)) {
            await Future<void>.delayed(_retryBackoff);
            continue;
          }
          rethrow;
        }
      }
      _debugLog('connect failed: $lastError');
      await AppLogger.error('wallet connect failed', lastError);
      return null;
    } catch (error, stackTrace) {
      assert(() {
        // ignore: avoid_print
        print('[WalletService] connect error: $error');
        // ignore: avoid_print
        print('[WalletService] stack: $stackTrace');
        return true;
      }());
      await AppLogger.error('wallet connect exception', error, stackTrace);
      return null;
    }
  }

  Future<List<Uint8List>> signAndSendTransactions(
    List<Uint8List> transactions,
  ) async {
    if (_connection == null) return const [];
    final result = await _withReauthorizedClient((client) async {
      await AppLogger.info('wallet signAndSend txCount=${transactions.length}');
      final capabilities = await client.getCapabilities();
      await AppLogger.info('wallet capabilities=$capabilities');
      final signed = await client
          .signAndSendTransactions(transactions: transactions)
          .timeout(_authorizeTimeout);
      await AppLogger.info(
        'wallet signAndSend returned signatures=${signed.signatures.length}',
      );
      return signed.signatures;
    });
    return result ?? const [];
  }

  Future<String?> signAndSendTransaction(Uint8List transaction) async {
    final signatures = await signAndSendTransactions([transaction]);
    if (signatures.isEmpty) return null;
    return base58encode(signatures.first);
  }

  Future<String?> signAndSendTransactionWithFallback({
    required Uint8List transaction,
    required RpcClient rpc,
  }) async {
    final directSignature = await signAndSendTransaction(transaction);
    if (directSignature != null) return directSignature;

    await AppLogger.info(
      'wallet signAndSend empty; trying signTransactions fallback',
    );
    final signedTx = await signTransaction(transaction);
    if (signedTx == null) return null;
    final signature = await rpc.sendTransaction(
      base64Encode(signedTx),
      preflightCommitment: Commitment.confirmed,
      maxRetries: 3,
    );
    await AppLogger.info('rpc send signed wallet tx signature=$signature');
    return signature;
  }

  Future<Uint8List?> signTransaction(Uint8List transaction) async {
    if (_connection == null) return null;
    return _withReauthorizedClient((client) async {
      await AppLogger.info(
        'wallet signTransactions bytes=${transaction.length}',
      );
      final signed = await client
          .signTransactions(transactions: [transaction])
          .timeout(_authorizeTimeout);
      await AppLogger.info(
        'wallet signTransactions returned payloads=${signed.signedPayloads.length}',
      );
      if (signed.signedPayloads.isEmpty) return null;
      return signed.signedPayloads.first;
    });
  }

  Future<void> disconnect() async {
    _connection = null;
  }

  Future<WalletConnection?> _connectOnce() async {
    LocalAssociationScenario? scenario;
    try {
      scenario = await LocalAssociationScenario.create();
      await AppLogger.info('wallet scenario created');
      final clientFuture = scenario.start().timeout(_authorizeTimeout);
      // This launches the wallet picker/activity. Without it, many Android
      // wallets never surface the authorize request.
      // ignore: discarded_futures
      scenario.startActivityForResult(null);
      final client = await clientFuture;
      await AppLogger.info('wallet client started');
      await Future<void>.delayed(_associationSettleDelay);

      final result = await client
          .authorize(
            identityName: _identityName,
            identityUri: _identityUri,
            cluster: RpcConfig.cluster,
          )
          .timeout(_authorizeTimeout);
      if (result == null) return null;

      final connection = WalletConnection(
        address: base58encode(result.publicKey),
        authToken: result.authToken,
        publicKeyBytes: result.publicKey,
      );
      _connection = connection;
      await AppLogger.info('wallet authorized address=${connection.address}');
      return connection;
    } finally {
      await scenario?.close();
      await AppLogger.info('wallet scenario closed');
    }
  }

  Future<T?> _withReauthorizedClient<T>(
    Future<T?> Function(MobileWalletAdapterClient client) action,
  ) async {
    final connection = _connection;
    if (connection == null) return null;

    LocalAssociationScenario? scenario;
    try {
      scenario = await LocalAssociationScenario.create();
      await AppLogger.info('wallet reauthorize scenario created');
      final clientFuture = scenario.start().timeout(_authorizeTimeout);
      // ignore: discarded_futures
      scenario.startActivityForResult(null);
      final client = await clientFuture;
      await Future<void>.delayed(_associationSettleDelay);

      var result = await client
          .reauthorize(
            identityName: _identityName,
            identityUri: _identityUri,
            authToken: connection.authToken,
          )
          .timeout(_authorizeTimeout);
      if (result == null) {
        await AppLogger.info(
          'wallet reauthorize returned null; trying authorize',
        );
        result = await client
            .authorize(
              identityName: _identityName,
              identityUri: _identityUri,
              cluster: RpcConfig.cluster,
            )
            .timeout(_authorizeTimeout);
      }
      if (result == null) {
        await AppLogger.error('wallet authorize/reauthorize returned null');
        return null;
      }

      _connection = WalletConnection(
        address: base58encode(result.publicKey),
        authToken: result.authToken,
        publicKeyBytes: result.publicKey,
      );
      await AppLogger.info(
        'wallet reauthorized address=${_connection!.address}',
      );
      return action(client);
    } finally {
      await scenario?.close();
      await AppLogger.info('wallet reauthorize scenario closed');
    }
  }

  bool _isTransientAssociationError(Object error) {
    final text = error.toString().toLowerCase();
    return text.contains('econnrefused') ||
        text.contains('connection refused') ||
        text.contains('failed establishing a websocket connection') ||
        text.contains('websocketexception') ||
        text.contains('failed to connect') ||
        text.contains('timeoutexception') ||
        text.contains('timed out');
  }

  bool _isUserRejected(Object error) {
    final text = error.toString().toLowerCase();
    return text.contains('user rejected') || text.contains('declined');
  }

  static void _debugLog(String message) {
    assert(() {
      // ignore: avoid_print
      print('[WalletService] $message');
      return true;
    }());
  }
}
