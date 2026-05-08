import 'dart:async';
import 'dart:typed_data';

import 'package:solana/base58.dart';
import 'package:solana_mobile_client/solana_mobile_client.dart';

import '../config/rpc_config.dart';

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
      return null;
    } catch (error, stackTrace) {
      assert(() {
        // ignore: avoid_print
        print('[WalletService] connect error: $error');
        // ignore: avoid_print
        print('[WalletService] stack: $stackTrace');
        return true;
      }());
      return null;
    }
  }

  Future<List<Uint8List>> signAndSendTransactions(
    List<Uint8List> transactions,
  ) async {
    if (_connection == null) return const [];
    final result = await _withReauthorizedClient((client) async {
      final signed = await client
          .signAndSendTransactions(transactions: transactions)
          .timeout(_authorizeTimeout);
      return signed.signatures;
    });
    return result ?? const [];
  }

  Future<String?> signAndSendTransaction(Uint8List transaction) async {
    final signatures = await signAndSendTransactions([transaction]);
    if (signatures.isEmpty) return null;
    return base58encode(signatures.first);
  }

  Future<void> disconnect() async {
    _connection = null;
  }

  Future<WalletConnection?> _connectOnce() async {
    LocalAssociationScenario? scenario;
    try {
      scenario = await LocalAssociationScenario.create();
      final clientFuture = scenario.start().timeout(_authorizeTimeout);
      // This launches the wallet picker/activity. Without it, many Android
      // wallets never surface the authorize request.
      // ignore: discarded_futures
      scenario.startActivityForResult(null);
      final client = await clientFuture;
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
      return connection;
    } finally {
      await scenario?.close();
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
      final clientFuture = scenario.start().timeout(_authorizeTimeout);
      // ignore: discarded_futures
      scenario.startActivityForResult(null);
      final client = await clientFuture;
      await Future<void>.delayed(_associationSettleDelay);

      final result = await client
          .reauthorize(
            identityName: _identityName,
            identityUri: _identityUri,
            authToken: connection.authToken,
          )
          .timeout(_authorizeTimeout);
      if (result == null) return null;

      _connection = WalletConnection(
        address: base58encode(result.publicKey),
        authToken: result.authToken,
        publicKeyBytes: result.publicKey,
      );
      return action(client);
    } finally {
      await scenario?.close();
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
