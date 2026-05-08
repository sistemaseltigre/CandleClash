import 'dart:typed_data';

import 'package:solana/solana.dart';

import '../config/constants.dart';
import '../models/daily_player.dart';
import '../models/daily_pool.dart';
import '../models/game_round.dart';
import '../models/player_profile.dart';
import '../models/player_vault.dart';

class CandleClashProgram {
  CandleClashProgram();

  final Ed25519HDPublicKey programId = Ed25519HDPublicKey.fromBase58(
    AppConstants.candleClashProgramId,
  );

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

  int currentUtcDayId() => DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000 ~/ 86400;

  Future<PlayerVault> fetchVault(String playerAddress) async {
    // TODO: decode PlayerVault account via generated Anchor IDL.
    return PlayerVault.empty.copyFor(playerAddress);
  }

  Future<PlayerProfile> fetchProfile(String playerAddress) async {
    // TODO: decode PlayerProfile account via generated Anchor IDL.
    return PlayerProfile.empty.copyFor(playerAddress);
  }

  Future<DailyPool> fetchDailyPool() async {
    // TODO: query DailyPool PDA for currentUtcDayId().
    return DailyPool(
      dayId: currentUtcDayId(),
      totalPoolLamports: 0,
      totalGames: 0,
      totalPlayers: 0,
    );
  }

  Future<List<DailyPlayer>> fetchLeaderboard() async {
    // TODO: getProgramAccounts filtered by DailyPlayer discriminator/day_id.
    return const [];
  }

  Future<Uint8List> buildInitializePlayerTransaction(String playerAddress) async {
    throw UnimplementedError('Build initialize_player from Anchor IDL.');
  }

  Future<Uint8List> buildDepositTransaction({
    required String playerAddress,
    required int lamports,
  }) async {
    throw UnimplementedError('Build deposit from Anchor IDL.');
  }

  Future<Uint8List> buildWithdrawTransaction({
    required String playerAddress,
    required int lamports,
  }) async {
    throw UnimplementedError('Build withdraw from Anchor IDL.');
  }

  Future<Ed25519HDKeyPair> createSessionAuthority() => Ed25519HDKeyPair.random();

  Future<Uint8List> buildStartSessionTransaction({
    required String playerAddress,
    required String sessionAuthority,
    required int maxSpendLamports,
  }) async {
    throw UnimplementedError('Build start_session from Anchor IDL.');
  }

  Future<Uint8List> buildStartRoundTransaction({
    required String playerAddress,
    required String sessionAuthority,
    required int roundId,
    required RoundDirection direction,
    required int dayId,
  }) async {
    throw UnimplementedError('Build start_round signed by session authority.');
  }

  Future<Uint8List> buildSettleRoundTransaction({
    required String playerAddress,
    required String sessionAuthority,
    required int roundId,
  }) async {
    throw UnimplementedError('Build settle_round signed by session authority.');
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
