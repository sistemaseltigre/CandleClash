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

class WalletService {
  LocalAssociationScenario? _scenario;
  MobileWalletAdapterClient? _client;
  WalletConnection? _connection;

  WalletConnection? get connection => _connection;

  Future<bool> get isAvailable => LocalAssociationScenario.isAvailable();

  Future<WalletConnection?> connect() async {
    _scenario = await LocalAssociationScenario.create();
    _client = await _scenario!.start();
    final result = await _client!.authorize(
      identityName: 'Candle Clash',
      identityUri: Uri.parse('https://candleclash.dev'),
      cluster: RpcConfig.cluster,
    );
    if (result == null) return null;

    _connection = WalletConnection(
      address: base58encode(result.publicKey),
      authToken: result.authToken,
      publicKeyBytes: result.publicKey,
    );
    return _connection;
  }

  Future<List<Uint8List>> signAndSendTransactions(
    List<Uint8List> transactions,
  ) async {
    final client = _client;
    if (client == null) return const [];
    final result = await client.signAndSendTransactions(
      transactions: transactions,
    );
    return result.signatures;
  }

  Future<void> disconnect() async {
    final connection = _connection;
    final client = _client;
    if (connection != null && client != null) {
      await client.deauthorize(authToken: connection.authToken);
    }
    await _scenario?.close();
    _connection = null;
    _client = null;
    _scenario = null;
  }
}
