import 'package:solana/solana.dart';

import '../config/rpc_config.dart';

class SolanaService {
  SolanaService({RpcClient? rpc})
    : rpc = rpc ?? RpcClient(RpcConfig.devnetRpcUrl);

  final RpcClient rpc;
  static const _balanceTimeout = Duration(seconds: 4);

  Future<double> getSolBalance(String address) async {
    return getLamportBalance(address).then((value) => value / lamportsPerSol);
  }

  Future<int> getLamportBalance(String address) async {
    final result = await rpc.getBalance(address).timeout(_balanceTimeout);
    return result.value;
  }
}
