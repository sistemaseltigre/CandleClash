# Candle Clash

Mobile long/short SOL/USD prediction game MVP.

## Structure

- `anchor/`: Anchor Solana program and tests.
- `app/`: Flutter + Flame mobile app skeleton.

## Devnet deployment

Program ID:

```text
E5bjWeyYLChSt2RMZUH3f9QVyCvU9z1sBRyhRB4jTgL3
```

Current MVP settlement tests use `MockPriceFeed` so local/devnet tests are deterministic. Before production, replace the mock reader in the Anchor program with the official Pyth SOL/USD devnet price account and set:

- `app/lib/config/constants.dart`: `pythSolUsdDevnetPriceAccount`
- `app/lib/config/rpc_config.dart`: Triton One devnet RPC/WebSocket URL
- `app/lib/config/constants.dart`: Titan or preferred visual price endpoint

## Commands

```bash
cd anchor
anchor test
anchor test --skip-build --skip-deploy --provider.cluster devnet

cd ../app
flutter analyze
flutter test
```
