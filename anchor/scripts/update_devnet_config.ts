import * as anchor from "@coral-xyz/anchor";
import { Program } from "@coral-xyz/anchor";
import { CandleClash } from "../target/types/candle_clash";

const ENTRY_FEE = new anchor.BN(20_000);
const POOL_FEE = new anchor.BN(15_000);
const TREASURY_FEE = new anchor.BN(5_000);
const ROUND_SECONDS = new anchor.BN(5);
const SESSION_SECONDS = new anchor.BN(3_600);
const DEFAULT_SESSION_LIMIT = new anchor.BN(1_000_000);

async function main() {
  anchor.setProvider(anchor.AnchorProvider.env());
  const provider = anchor.getProvider() as anchor.AnchorProvider;
  const program = anchor.workspace.candleClash as Program<CandleClash>;

  const [globalConfig] = anchor.web3.PublicKey.findProgramAddressSync(
    [Buffer.from("global_config")],
    program.programId
  );

  const current = await program.account.globalConfig.fetch(globalConfig);
  console.log("program", program.programId.toBase58());
  console.log("globalConfig", globalConfig.toBase58());
  console.log("admin", current.admin.toBase58());
  console.log("wallet", provider.wallet.publicKey.toBase58());
  console.log("currentEntryFee", current.entryFeeLamports.toString());

  const signature = await program.methods
    .updateConfig(
      current.treasury,
      ENTRY_FEE,
      POOL_FEE,
      TREASURY_FEE,
      ROUND_SECONDS,
      SESSION_SECONDS,
      DEFAULT_SESSION_LIMIT
    )
    .accounts({
      globalConfig,
      admin: provider.wallet.publicKey,
    })
    .rpc();

  const updated = await program.account.globalConfig.fetch(globalConfig);
  console.log("signature", signature);
  console.log("updatedEntryFee", updated.entryFeeLamports.toString());
  console.log("updatedPoolFee", updated.poolFeeLamports.toString());
  console.log("updatedTreasuryFee", updated.treasuryFeeLamports.toString());
  console.log("updatedRoundSeconds", updated.roundDurationSeconds.toString());
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
