class RpcConfig {
  const RpcConfig._();

  // Pass private/provider RPCs at build time:
  // flutter run --dart-define=CANDLE_CLASH_RPC_URL=https://... \
  //   --dart-define=CANDLE_CLASH_WS_URL=wss://...
  static const devnetRpcUrl = String.fromEnvironment(
    'CANDLE_CLASH_RPC_URL',
    defaultValue: 'https://api.devnet.solana.com',
  );
  static const devnetWebsocketUrl = String.fromEnvironment(
    'CANDLE_CLASH_WS_URL',
    defaultValue: 'wss://api.devnet.solana.com',
  );
  static const cluster = 'devnet';
}
