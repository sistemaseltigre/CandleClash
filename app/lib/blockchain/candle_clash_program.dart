import 'dart:typed_data';

import 'package:solana/anchor.dart';
import 'package:solana/dto.dart' hide Instruction;
import 'package:solana/encoder.dart';
import 'package:solana/solana.dart';

import '../config/constants.dart';
import '../config/rpc_config.dart';
import '../models/daily_player.dart';
import '../models/daily_pool.dart';
import '../models/game_round.dart';
import '../models/player_profile.dart';
import '../models/player_vault.dart';
import '../services/app_logger.dart';

class CandleClashProgram {
  CandleClashProgram({RpcClient? rpc})
    : rpc = rpc ?? RpcClient(RpcConfig.devnetRpcUrl);

  final RpcClient rpc;

  final Ed25519HDPublicKey programId = Ed25519HDPublicKey.fromBase58(
    AppConstants.candleClashProgramId,
  );
  final Ed25519HDPublicKey systemProgramId = SystemProgram.id;
  static const _accountReadTimeout = Duration(seconds: 4);

  Future<Ed25519HDPublicKey> playerProfilePda(String playerAddress) {
    return Ed25519HDPublicKey.findProgramAddress(
      seeds: [
        'player_profile'.codeUnits,
        Ed25519HDPublicKey.fromBase58(playerAddress).bytes,
      ],
      programId: programId,
    );
  }

  Future<Ed25519HDPublicKey> playerVaultPda(String playerAddress) {
    return Ed25519HDPublicKey.findProgramAddress(
      seeds: [
        'player_vault'.codeUnits,
        Ed25519HDPublicKey.fromBase58(playerAddress).bytes,
      ],
      programId: programId,
    );
  }

  Future<Ed25519HDPublicKey> globalConfigPda() {
    return Ed25519HDPublicKey.findProgramAddress(
      seeds: ['global_config'.codeUnits],
      programId: programId,
    );
  }

  Future<Ed25519HDPublicKey> mockPriceFeedPda() {
    return Ed25519HDPublicKey.findProgramAddress(
      seeds: ['mock_price_feed'.codeUnits],
      programId: programId,
    );
  }

  Ed25519HDPublicKey officialPriceFeed() {
    return Ed25519HDPublicKey.fromBase58(
      AppConstants.pythSolUsdDevnetPriceAccount,
    );
  }

  Future<Ed25519HDPublicKey> playerSessionPda({
    required String playerAddress,
    required Ed25519HDPublicKey sessionAuthority,
  }) {
    return Ed25519HDPublicKey.findProgramAddress(
      seeds: [
        'player_session'.codeUnits,
        Ed25519HDPublicKey.fromBase58(playerAddress).bytes,
        sessionAuthority.bytes,
      ],
      programId: programId,
    );
  }

  Future<Ed25519HDPublicKey> dailyPoolPda(int dayId) {
    return Ed25519HDPublicKey.findProgramAddress(
      seeds: ['daily_pool'.codeUnits, _u64List(dayId)],
      programId: programId,
    );
  }

  Future<Ed25519HDPublicKey> dailyPlayerPda({
    required int dayId,
    required String playerAddress,
  }) {
    return Ed25519HDPublicKey.findProgramAddress(
      seeds: [
        'daily_player'.codeUnits,
        _u64List(dayId),
        Ed25519HDPublicKey.fromBase58(playerAddress).bytes,
      ],
      programId: programId,
    );
  }

  Future<Ed25519HDPublicKey> gameRoundPda({
    required String playerAddress,
    required int roundId,
  }) {
    return Ed25519HDPublicKey.findProgramAddress(
      seeds: [
        'game_round'.codeUnits,
        Ed25519HDPublicKey.fromBase58(playerAddress).bytes,
        _u64List(roundId),
      ],
      programId: programId,
    );
  }

  int currentUtcDayId() =>
      DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000 ~/ 86400;

  Future<PlayerVault> fetchVault(String playerAddress) async {
    final pda = await playerVaultPda(playerAddress);
    final data = await _accountBytes(pda);
    if (data == null || data.length < 65) {
      return PlayerVault.empty.copyFor(playerAddress);
    }
    final reader = _Reader(data);
    reader.skip(8 + 32);
    return PlayerVault(
      player: playerAddress,
      balanceLamports: reader.u64(),
      totalDepositedLamports: reader.u64(),
      totalWithdrawnLamports: reader.u64(),
    );
  }

  Future<PlayerProfile> fetchProfile(String playerAddress) async {
    final pda = await playerProfilePda(playerAddress);
    final data = await _accountBytes(pda);
    if (data == null || data.length < 153) {
      return PlayerProfile.empty.copyFor(playerAddress);
    }
    final reader = _Reader(data);
    reader.skip(8 + 32);
    final totalGames = reader.u64();
    final totalWins = reader.u64();
    final totalLosses = reader.u64();
    final totalLong = reader.u64();
    final totalShort = reader.u64();
    reader.skip(8 * 3);
    final exp = reader.u64();
    final level = reader.u64();
    final currentStreak = reader.u64();
    final bestStreak = reader.u64();
    return PlayerProfile(
      player: playerAddress,
      totalGames: totalGames,
      totalWins: totalWins,
      totalLosses: totalLosses,
      totalLong: totalLong,
      totalShort: totalShort,
      exp: exp,
      level: level,
      currentStreak: currentStreak,
      bestStreak: bestStreak,
    );
  }

  Future<DailyPool> fetchDailyPool() async {
    final dayId = currentUtcDayId();
    final pda = await dailyPoolPda(dayId);
    final data = await _accountBytes(pda);
    if (data != null && data.length >= 50) {
      final reader = _Reader(data);
      reader.skip(8);
      return DailyPool(
        dayId: reader.u64(),
        totalPoolLamports: reader.u64(),
        totalGames: reader.u64(),
        totalPlayers: reader.u64(),
      );
    }
    return DailyPool(
      dayId: dayId,
      totalPoolLamports: 0,
      totalGames: 0,
      totalPlayers: 0,
    );
  }

  Future<List<DailyPlayer>> fetchLeaderboard() async {
    final dayId = currentUtcDayId();
    try {
      final accounts = await rpc.getProgramAccounts(
        programId.toBase58(),
        encoding: Encoding.base64,
        commitment: Commitment.confirmed,
        filters: [
          const ProgramDataFilter.dataSize(129),
          ProgramDataFilter.memcmp(offset: 0, bytes: _dailyPlayerDiscriminator),
          ProgramDataFilter.memcmp(offset: 8, bytes: _u64List(dayId)),
        ],
      );
      final players = <DailyPlayer>[];
      for (final account in accounts) {
        final data = account.account.data;
        if (data is! BinaryAccountData || data.data.length < 129) continue;
        players.add(_decodeDailyPlayer(data.data));
      }
      players.sort((a, b) => b.dailyScore.compareTo(a.dailyScore));
      return players.take(50).toList(growable: false);
    } catch (error, stack) {
      await AppLogger.error('fetch leaderboard failed', error, stack);
      return const [];
    }
  }

  Future<Uint8List> buildInitializePlayerTransaction(
    String playerAddress,
  ) async {
    final player = Ed25519HDPublicKey.fromBase58(playerAddress);
    return _walletTransaction(
      payer: player,
      instructions: [await initializePlayerInstruction(playerAddress)],
    );
  }

  Future<Uint8List> buildDepositTransaction({
    required String playerAddress,
    required int lamports,
  }) async {
    final player = Ed25519HDPublicKey.fromBase58(playerAddress);
    return _walletTransaction(
      payer: player,
      instructions: [
        await depositInstruction(
          playerAddress: playerAddress,
          lamports: lamports,
        ),
      ],
    );
  }

  Future<Uint8List> buildWithdrawTransaction({
    required String playerAddress,
    required int lamports,
  }) async {
    final player = Ed25519HDPublicKey.fromBase58(playerAddress);
    return _walletTransaction(
      payer: player,
      instructions: [
        await withdrawInstruction(
          playerAddress: playerAddress,
          lamports: lamports,
        ),
      ],
    );
  }

  Future<Ed25519HDKeyPair> createSessionAuthority() =>
      Ed25519HDKeyPair.random();

  Future<Uint8List> buildStartSessionTransaction({
    required String playerAddress,
    required String sessionAuthority,
    required int maxSpendLamports,
  }) async {
    final player = Ed25519HDPublicKey.fromBase58(playerAddress);
    return _walletTransaction(
      payer: player,
      instructions: [
        await startSessionInstruction(
          playerAddress: playerAddress,
          sessionAuthority: Ed25519HDPublicKey.fromBase58(sessionAuthority),
          maxSpendLamports: maxSpendLamports,
        ),
      ],
    );
  }

  Future<Uint8List> buildSetupTransaction({
    required String playerAddress,
    required Ed25519HDPublicKey sessionAuthority,
    required int depositLamports,
    required int maxSpendLamports,
    required int sessionFundingLamports,
  }) async {
    final player = Ed25519HDPublicKey.fromBase58(playerAddress);
    final instructions = <Instruction>[
      await initializePlayerInstruction(playerAddress),
      if (sessionFundingLamports > 0)
        SystemInstruction.transfer(
          fundingAccount: player,
          recipientAccount: sessionAuthority,
          lamports: sessionFundingLamports,
        ),
      if (depositLamports > 0)
        await depositInstruction(
          playerAddress: playerAddress,
          lamports: depositLamports,
        ),
      await startSessionInstruction(
        playerAddress: playerAddress,
        sessionAuthority: sessionAuthority,
        maxSpendLamports: maxSpendLamports,
      ),
    ];
    return _walletTransaction(payer: player, instructions: instructions);
  }

  Future<Uint8List> buildFundSessionAuthorityTransaction({
    required String playerAddress,
    required Ed25519HDPublicKey sessionAuthority,
    required int lamports,
  }) async {
    final player = Ed25519HDPublicKey.fromBase58(playerAddress);
    return _walletTransaction(
      payer: player,
      instructions: [
        SystemInstruction.transfer(
          fundingAccount: player,
          recipientAccount: sessionAuthority,
          lamports: lamports,
        ),
      ],
    );
  }

  Future<Uint8List> buildStartRoundTransaction({
    required String playerAddress,
    required String sessionAuthority,
    required int roundId,
    required RoundDirection direction,
    required int dayId,
  }) async {
    throw UnimplementedError(
      'Use sendStartRound with local session authority.',
    );
  }

  Future<Uint8List> buildSettleRoundTransaction({
    required String playerAddress,
    required String sessionAuthority,
    required int roundId,
  }) async {
    throw UnimplementedError(
      'Use sendSettleRound with local session authority.',
    );
  }

  Future<String> sendStartRound({
    required String playerAddress,
    required Ed25519HDKeyPair sessionAuthority,
    required int roundId,
    required RoundDirection direction,
  }) async {
    final ix = await startRoundInstruction(
      playerAddress: playerAddress,
      sessionAuthority: sessionAuthority.publicKey,
      roundId: roundId,
      direction: direction,
      dayId: currentUtcDayId(),
    );
    return _signedSend(Message.only(ix), [sessionAuthority]);
  }

  Future<String> sendSettleRound({
    required String playerAddress,
    required Ed25519HDKeyPair sessionAuthority,
    required int roundId,
  }) async {
    final ix = await settleRoundInstruction(
      playerAddress: playerAddress,
      sessionAuthority: sessionAuthority.publicKey,
      roundId: roundId,
    );
    return _signedSend(Message.only(ix), [sessionAuthority]);
  }

  Future<GameRound?> fetchRound({
    required String playerAddress,
    required int roundId,
  }) async {
    final pda = await gameRoundPda(
      playerAddress: playerAddress,
      roundId: roundId,
    );
    final data = await _accountBytes(pda);
    if (data == null || data.length < 148) return null;
    final reader = _Reader(data);
    reader.skip(8 + 32 + 32);
    final storedRoundId = reader.u64();
    reader.skip(8);
    final direction = reader.u8() == 0
        ? RoundDirection.long
        : RoundDirection.short;
    final entryFee = reader.u64();
    final startPrice = reader.i64() / 1000000;
    final endPrice = reader.i64() / 1000000;
    reader.skip(8 + 8);
    final settled = reader.readBool();
    final won = reader.readBool();
    final scoreDelta = reader.u64();
    final expDelta = reader.u64();
    return GameRound(
      roundId: storedRoundId,
      direction: direction,
      startPrice: startPrice,
      endPrice: endPrice,
      settled: settled,
      won: won,
      scoreDelta: scoreDelta,
      expDelta: expDelta,
      entryFeeLamports: entryFee,
    );
  }

  Future<AnchorInstruction> initializePlayerInstruction(
    String playerAddress,
  ) async {
    final player = Ed25519HDPublicKey.fromBase58(playerAddress);
    return AnchorInstruction.forMethod(
      programId: programId,
      namespace: 'global',
      method: 'initialize_player',
      accounts: [
        AccountMeta.writeable(pubKey: player, isSigner: true),
        AccountMeta.writeable(
          pubKey: await playerProfilePda(playerAddress),
          isSigner: false,
        ),
        AccountMeta.writeable(
          pubKey: await playerVaultPda(playerAddress),
          isSigner: false,
        ),
        AccountMeta.readonly(pubKey: systemProgramId, isSigner: false),
      ],
    );
  }

  Future<AnchorInstruction> depositInstruction({
    required String playerAddress,
    required int lamports,
  }) async {
    final player = Ed25519HDPublicKey.fromBase58(playerAddress);
    return AnchorInstruction.forMethod(
      programId: programId,
      namespace: 'global',
      method: 'deposit',
      arguments: ByteArray.u64(lamports),
      accounts: [
        AccountMeta.writeable(pubKey: player, isSigner: true),
        AccountMeta.writeable(
          pubKey: await playerVaultPda(playerAddress),
          isSigner: false,
        ),
        AccountMeta.readonly(pubKey: systemProgramId, isSigner: false),
      ],
    );
  }

  Future<AnchorInstruction> withdrawInstruction({
    required String playerAddress,
    required int lamports,
  }) async {
    final player = Ed25519HDPublicKey.fromBase58(playerAddress);
    return AnchorInstruction.forMethod(
      programId: programId,
      namespace: 'global',
      method: 'withdraw',
      arguments: ByteArray.u64(lamports),
      accounts: [
        AccountMeta.writeable(pubKey: player, isSigner: true),
        AccountMeta.writeable(
          pubKey: await playerVaultPda(playerAddress),
          isSigner: false,
        ),
      ],
    );
  }

  Future<AnchorInstruction> startSessionInstruction({
    required String playerAddress,
    required Ed25519HDPublicKey sessionAuthority,
    required int maxSpendLamports,
  }) async {
    final player = Ed25519HDPublicKey.fromBase58(playerAddress);
    return AnchorInstruction.forMethod(
      programId: programId,
      namespace: 'global',
      method: 'start_session',
      arguments: ByteArray.merge([
        sessionAuthority.toByteArray(),
        ByteArray.u64(maxSpendLamports),
      ]),
      accounts: [
        AccountMeta.readonly(pubKey: await globalConfigPda(), isSigner: false),
        AccountMeta.writeable(pubKey: player, isSigner: true),
        AccountMeta.readonly(
          pubKey: await playerVaultPda(playerAddress),
          isSigner: false,
        ),
        AccountMeta.writeable(
          pubKey: await playerSessionPda(
            playerAddress: playerAddress,
            sessionAuthority: sessionAuthority,
          ),
          isSigner: false,
        ),
        AccountMeta.readonly(pubKey: systemProgramId, isSigner: false),
      ],
    );
  }

  Future<AnchorInstruction> startRoundInstruction({
    required String playerAddress,
    required Ed25519HDPublicKey sessionAuthority,
    required int roundId,
    required RoundDirection direction,
    required int dayId,
  }) async {
    return AnchorInstruction.forMethod(
      programId: programId,
      namespace: 'global',
      method: 'start_round',
      arguments: ByteArray.merge([
        ByteArray.u64(roundId),
        ByteArray.u8(direction == RoundDirection.long ? 0 : 1),
        ByteArray.u64(dayId),
      ]),
      accounts: [
        AccountMeta.readonly(pubKey: await globalConfigPda(), isSigner: false),
        AccountMeta.readonly(
          pubKey: Ed25519HDPublicKey.fromBase58(playerAddress),
          isSigner: false,
        ),
        AccountMeta.writeable(pubKey: sessionAuthority, isSigner: true),
        AccountMeta.writeable(
          pubKey: await playerProfilePda(playerAddress),
          isSigner: false,
        ),
        AccountMeta.writeable(
          pubKey: await playerVaultPda(playerAddress),
          isSigner: false,
        ),
        AccountMeta.writeable(
          pubKey: await playerSessionPda(
            playerAddress: playerAddress,
            sessionAuthority: sessionAuthority,
          ),
          isSigner: false,
        ),
        AccountMeta.writeable(
          pubKey: await dailyPoolPda(dayId),
          isSigner: false,
        ),
        AccountMeta.writeable(
          pubKey: await dailyPlayerPda(
            dayId: dayId,
            playerAddress: playerAddress,
          ),
          isSigner: false,
        ),
        AccountMeta.writeable(
          pubKey: await gameRoundPda(
            playerAddress: playerAddress,
            roundId: roundId,
          ),
          isSigner: false,
        ),
        AccountMeta.readonly(pubKey: officialPriceFeed(), isSigner: false),
        AccountMeta.readonly(pubKey: systemProgramId, isSigner: false),
      ],
    );
  }

  Future<AnchorInstruction> settleRoundInstruction({
    required String playerAddress,
    required Ed25519HDPublicKey sessionAuthority,
    required int roundId,
  }) async {
    final dayId = currentUtcDayId();
    return AnchorInstruction.forMethod(
      programId: programId,
      namespace: 'global',
      method: 'settle_round',
      arguments: ByteArray.u64(roundId),
      accounts: [
        AccountMeta.readonly(pubKey: sessionAuthority, isSigner: true),
        AccountMeta.writeable(
          pubKey: await playerProfilePda(playerAddress),
          isSigner: false,
        ),
        AccountMeta.writeable(
          pubKey: await dailyPlayerPda(
            dayId: dayId,
            playerAddress: playerAddress,
          ),
          isSigner: false,
        ),
        AccountMeta.writeable(
          pubKey: await playerVaultPda(playerAddress),
          isSigner: false,
        ),
        AccountMeta.writeable(
          pubKey: await gameRoundPda(
            playerAddress: playerAddress,
            roundId: roundId,
          ),
          isSigner: false,
        ),
        AccountMeta.readonly(pubKey: officialPriceFeed(), isSigner: false),
      ],
    );
  }

  Future<Uint8List> _walletTransaction({
    required Ed25519HDPublicKey payer,
    required List<Instruction> instructions,
  }) async {
    final latest = await rpc.getLatestBlockhash(
      commitment: Commitment.confirmed,
    );
    final compiled = Message(
      instructions: instructions,
    ).compile(recentBlockhash: latest.value.blockhash, feePayer: payer);
    final signatures = List.generate(
      compiled.requiredSignatureCount,
      (index) => Signature(
        List<int>.filled(64, 0),
        publicKey: compiled.accountKeys[index],
      ),
    );
    return Uint8List.fromList(
      SignedTx(
        compiledMessage: compiled,
        signatures: signatures,
      ).toByteArray().toList(),
    );
  }

  Future<String> _signedSend(
    Message message,
    List<Ed25519HDKeyPair> signers,
  ) async {
    final signed = await rpc.signMessage(
      message,
      signers,
      commitment: Commitment.confirmed,
    );
    await AppLogger.info('send tx ${signed.id}');
    return rpc.sendTransaction(
      signed.encode(),
      preflightCommitment: Commitment.confirmed,
      maxRetries: 3,
    );
  }

  Future<List<int>?> _accountBytes(Ed25519HDPublicKey pubkey) async {
    try {
      final account = await rpc
          .getAccountInfo(
            pubkey.toBase58(),
            encoding: Encoding.base64,
            commitment: Commitment.confirmed,
          )
          .timeout(_accountReadTimeout);
      final data = account.value?.data;
      if (data is BinaryAccountData) return data.data;
    } catch (error, stack) {
      await AppLogger.error(
        'fetch account ${pubkey.toBase58()} failed',
        error,
        stack,
      );
    }
    return null;
  }

  List<int> _u64List(int value) => ByteArray.u64(value).toList(growable: false);

  DailyPlayer _decodeDailyPlayer(List<int> data) {
    final reader = _Reader(data);
    reader.skip(8);
    final dayId = reader.u64();
    final player = Ed25519HDPublicKey(reader.bytes(32)).toBase58();
    final dailyScore = reader.u64();
    final dailyGames = reader.u64();
    final dailyWins = reader.u64();
    final dailyLosses = reader.u64();
    final dailyLong = reader.u64();
    final dailyShort = reader.u64();
    final dailySpentLamports = reader.u64();
    final dailyPoolContributedLamports = reader.u64();
    return DailyPlayer(
      dayId: dayId,
      player: player,
      dailyScore: dailyScore,
      dailyGames: dailyGames,
      dailyWins: dailyWins,
      dailyLosses: dailyLosses,
      dailyLong: dailyLong,
      dailyShort: dailyShort,
      dailySpentLamports: dailySpentLamports,
      dailyPoolContributedLamports: dailyPoolContributedLamports,
    );
  }
}

const _dailyPlayerDiscriminator = [2, 123, 72, 37, 246, 127, 78, 33];

class _Reader {
  _Reader(List<int> data)
    : _data = ByteData.sublistView(Uint8List.fromList(data));

  final ByteData _data;
  int _offset = 0;

  void skip(int bytes) {
    _offset += bytes;
  }

  int u64() {
    final value = _data.getUint64(_offset, Endian.little);
    _offset += 8;
    return value;
  }

  int i64() {
    final value = _data.getInt64(_offset, Endian.little);
    _offset += 8;
    return value;
  }

  int u8() {
    final value = _data.getUint8(_offset);
    _offset += 1;
    return value;
  }

  bool readBool() => u8() != 0;

  List<int> bytes(int length) {
    final value = _data.buffer.asUint8List(_offset, length).toList();
    _offset += length;
    return value;
  }
}

extension on PlayerVault {
  PlayerVault copyFor(String playerAddress) => PlayerVault(
    player: playerAddress,
    balanceLamports: balanceLamports,
    totalDepositedLamports: totalDepositedLamports,
    totalWithdrawnLamports: totalWithdrawnLamports,
  );
}

extension on PlayerProfile {
  PlayerProfile copyFor(String playerAddress) => PlayerProfile(
    player: playerAddress,
    totalGames: totalGames,
    totalWins: totalWins,
    totalLosses: totalLosses,
    totalLong: totalLong,
    totalShort: totalShort,
    exp: exp,
    level: level,
    currentStreak: currentStreak,
    bestStreak: bestStreak,
  );
}
