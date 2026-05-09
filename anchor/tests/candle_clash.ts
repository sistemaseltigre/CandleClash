import * as anchor from "@coral-xyz/anchor";
import { Program } from "@coral-xyz/anchor";
import { expect } from "chai";
import { CandleClash } from "../target/types/candle_clash";

const LAMPORTS_PER_SOL = anchor.web3.LAMPORTS_PER_SOL;
const ENTRY_FEE = new anchor.BN(20_000);
const POOL_FEE = new anchor.BN(15_000);
const TREASURY_FEE = new anchor.BN(5_000);
const SESSION_LIMIT = new anchor.BN(900_000);
const DEPOSIT_AMOUNT = new anchor.BN(1_000_000);

describe("candle_clash", () => {
  anchor.setProvider(anchor.AnchorProvider.env());

  const provider = anchor.getProvider() as anchor.AnchorProvider;
  const program = anchor.workspace.candleClash as Program<CandleClash>;
  const player = anchor.web3.Keypair.generate();
  const treasury = anchor.web3.Keypair.generate().publicKey;
  const sessionAuthority = anchor.web3.Keypair.generate();

  const pda = (seeds: Buffer[]) =>
    anchor.web3.PublicKey.findProgramAddressSync(seeds, program.programId)[0];
  const u64 = (value: number) =>
    new anchor.BN(value).toArrayLike(Buffer, "le", 8);
  const dayId = () => Math.floor(Date.now() / 1000 / 86_400);

  const globalConfig = pda([Buffer.from("global_config")]);
  const playerProfile = () =>
    pda([Buffer.from("player_profile"), player.publicKey.toBuffer()]);
  const playerVault = () =>
    pda([Buffer.from("player_vault"), player.publicKey.toBuffer()]);
  const playerSession = () =>
    pda([
      Buffer.from("player_session"),
      player.publicKey.toBuffer(),
      sessionAuthority.publicKey.toBuffer(),
    ]);
  const dailyPool = () => pda([Buffer.from("daily_pool"), u64(dayId())]);
  const dailyPlayer = () =>
    pda([
      Buffer.from("daily_player"),
      u64(dayId()),
      player.publicKey.toBuffer(),
    ]);
  const gameRound = (roundId: number) =>
    pda([Buffer.from("game_round"), player.publicKey.toBuffer(), u64(roundId)]);
  const priceFeed = pda([Buffer.from("mock_price_feed")]);

  async function airdrop(pubkey: anchor.web3.PublicKey, sol = 2) {
    const lamports = sol * LAMPORTS_PER_SOL;
    try {
      const sig = await provider.connection.requestAirdrop(pubkey, lamports);
      await provider.connection.confirmTransaction(sig, "confirmed");
    } catch (_error) {
      const tx = new anchor.web3.Transaction().add(
        anchor.web3.SystemProgram.transfer({
          fromPubkey: provider.wallet.publicKey,
          toPubkey: pubkey,
          lamports,
        })
      );
      await provider.sendAndConfirm(tx);
    }
  }

  async function sleep(ms: number) {
    await new Promise((resolve) => setTimeout(resolve, ms));
  }

  async function startRound(roundId: number, direction: number) {
    return program.methods
      .startRound(new anchor.BN(roundId), direction, new anchor.BN(dayId()))
      .accounts({
        globalConfig,
        player: player.publicKey,
        sessionAuthority: sessionAuthority.publicKey,
        playerProfile: playerProfile(),
        playerVault: playerVault(),
        playerSession: playerSession(),
        dailyPool: dailyPool(),
        dailyPlayer: dailyPlayer(),
        gameRound: gameRound(roundId),
        priceFeed,
        systemProgram: anchor.web3.SystemProgram.programId,
      })
      .signers([sessionAuthority])
      .rpc();
  }

  async function settleRound(roundId: number) {
    return program.methods
      .settleRound(new anchor.BN(roundId))
      .accounts({
        authority: sessionAuthority.publicKey,
        playerProfile: playerProfile(),
        dailyPlayer: dailyPlayer(),
        gameRound: gameRound(roundId),
        priceFeed,
      })
      .signers([sessionAuthority])
      .rpc();
  }

  before(async () => {
    await airdrop(player.publicKey);
    await airdrop(sessionAuthority.publicKey);
  });

  it("initializes config", async () => {
    await program.methods
      .initializeConfig(
        treasury,
        ENTRY_FEE,
        POOL_FEE,
        TREASURY_FEE,
        new anchor.BN(1),
        new anchor.BN(3600),
        SESSION_LIMIT
      )
      .accounts({
        globalConfig,
        admin: provider.wallet.publicKey,
        systemProgram: anchor.web3.SystemProgram.programId,
      })
      .rpc();

    const config = await program.account.globalConfig.fetch(globalConfig);
    expect(config.admin.toBase58()).to.eq(provider.wallet.publicKey.toBase58());
    expect(config.entryFeeLamports.toString()).to.eq(ENTRY_FEE.toString());
  });

  it("initializes mock oracle and player accounts", async () => {
    await program.methods
      .initializeMockPriceFeed(new anchor.BN(150_000_000))
      .accounts({
        admin: provider.wallet.publicKey,
        priceFeed,
        systemProgram: anchor.web3.SystemProgram.programId,
      })
      .rpc();

    await program.methods
      .initializePlayer()
      .accounts({
        player: player.publicKey,
        playerProfile: playerProfile(),
        playerVault: playerVault(),
        systemProgram: anchor.web3.SystemProgram.programId,
      })
      .signers([player])
      .rpc();

    const profile = await program.account.playerProfile.fetch(playerProfile());
    const vault = await program.account.playerVault.fetch(playerVault());
    expect(profile.player.toBase58()).to.eq(player.publicKey.toBase58());
    expect(vault.balanceLamports.toNumber()).to.eq(0);
  });

  it("deposits and withdraws internal balance", async () => {
    await program.methods
      .deposit(DEPOSIT_AMOUNT)
      .accounts({
        player: player.publicKey,
        playerVault: playerVault(),
        systemProgram: anchor.web3.SystemProgram.programId,
      })
      .signers([player])
      .rpc();

    let vault = await program.account.playerVault.fetch(playerVault());
    expect(vault.balanceLamports.toString()).to.eq(DEPOSIT_AMOUNT.toString());
    expect(vault.totalDepositedLamports.toString()).to.eq(
      DEPOSIT_AMOUNT.toString()
    );

    await program.methods
      .withdraw(new anchor.BN(100_000))
      .accounts({
        player: player.publicKey,
        playerVault: playerVault(),
      })
      .signers([player])
      .rpc();

    vault = await program.account.playerVault.fetch(playerVault());
    expect(vault.balanceLamports.toNumber()).to.eq(900_000);
    expect(vault.totalWithdrawnLamports.toNumber()).to.eq(100_000);
  });

  it("starts a delegated session", async () => {
    await program.methods
      .startSession(sessionAuthority.publicKey, SESSION_LIMIT)
      .accounts({
        globalConfig,
        player: player.publicKey,
        playerVault: playerVault(),
        playerSession: playerSession(),
        systemProgram: anchor.web3.SystemProgram.programId,
      })
      .signers([player])
      .rpc();

    const session = await program.account.playerSession.fetch(playerSession());
    expect(session.isActive).to.eq(true);
    expect(session.maxSpendLamports.toString()).to.eq(SESSION_LIMIT.toString());
  });

  it("starts and settles a winning long round", async () => {
    await startRound(1, 0);

    let round = await program.account.gameRound.fetch(gameRound(1));
    expect(round.direction).to.eq(0);
    expect(round.startPrice.toNumber()).to.eq(150_000_000);

    await program.methods
      .setMockPrice(new anchor.BN(151_000_000))
      .accounts({ admin: provider.wallet.publicKey, priceFeed })
      .rpc();
    await sleep(1200);
    await settleRound(1);

    round = await program.account.gameRound.fetch(gameRound(1));
    const profile = await program.account.playerProfile.fetch(playerProfile());
    const daily = await program.account.dailyPlayer.fetch(dailyPlayer());

    expect(round.settled).to.eq(true);
    expect(round.won).to.eq(true);
    expect(round.scoreDelta.toNumber()).to.eq(110);
    expect(round.expDelta.toNumber()).to.eq(27);
    expect(profile.totalWins.toNumber()).to.eq(1);
    expect(profile.exp.toNumber()).to.eq(27);
    expect(profile.level.toNumber()).to.eq(1);
    expect(daily.dailyWins.toNumber()).to.eq(1);
    expect(daily.dailyScore.toNumber()).to.eq(110);
  });

  it("starts and settles a losing short round and updates daily stats", async () => {
    await program.methods
      .setMockPrice(new anchor.BN(152_000_000))
      .accounts({ admin: provider.wallet.publicKey, priceFeed })
      .rpc();
    await startRound(2, 1);

    await program.methods
      .setMockPrice(new anchor.BN(153_000_000))
      .accounts({ admin: provider.wallet.publicKey, priceFeed })
      .rpc();
    await sleep(1200);
    await settleRound(2);

    const round = await program.account.gameRound.fetch(gameRound(2));
    const profile = await program.account.playerProfile.fetch(playerProfile());
    const daily = await program.account.dailyPlayer.fetch(dailyPlayer());
    const pool = await program.account.dailyPool.fetch(dailyPool());

    expect(round.won).to.eq(false);
    expect(round.scoreDelta.toNumber()).to.eq(10);
    expect(round.expDelta.toNumber()).to.eq(7);
    expect(profile.totalGames.toNumber()).to.eq(2);
    expect(profile.totalLosses.toNumber()).to.eq(1);
    expect(profile.exp.toNumber()).to.eq(34);
    expect(profile.level.toNumber()).to.eq(1);
    expect(daily.dailyGames.toNumber()).to.eq(2);
    expect(daily.dailyLosses.toNumber()).to.eq(1);
    expect(daily.dailyLong.toNumber()).to.eq(1);
    expect(daily.dailyShort.toNumber()).to.eq(1);
    expect(daily.dailyScore.toNumber()).to.eq(120);
    expect(pool.totalGames.toNumber()).to.eq(2);
    expect(pool.totalPoolLamports.toNumber()).to.eq(30_000);
  });
});
