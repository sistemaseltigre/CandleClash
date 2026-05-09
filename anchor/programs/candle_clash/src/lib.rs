use anchor_lang::prelude::*;
use anchor_lang::system_program;

declare_id!("E5bjWeyYLChSt2RMZUH3f9QVyCvU9z1sBRyhRB4jTgL3");

const GLOBAL_CONFIG_SEED: &[u8] = b"global_config";
const PLAYER_PROFILE_SEED: &[u8] = b"player_profile";
const PLAYER_VAULT_SEED: &[u8] = b"player_vault";
const PLAYER_SESSION_SEED: &[u8] = b"player_session";
const DAILY_POOL_SEED: &[u8] = b"daily_pool";
const DAILY_PLAYER_SEED: &[u8] = b"daily_player";
const GAME_ROUND_SEED: &[u8] = b"game_round";
const MOCK_PRICE_FEED_SEED: &[u8] = b"mock_price_feed";
const PYTH_SOL_USD_PRICE_FEED: Pubkey =
    pubkey!("7UVimffxr9ow1uXYxsr4LHAcV58mLzhmwaeKvJ1pjLiE");
const PYTH_SOL_USD_FEED_ID: [u8; 32] = [
    0xef, 0x0d, 0x8b, 0x6f, 0xda, 0x2c, 0xeb, 0xa4, 0x1d, 0xa1, 0x5d, 0x40, 0x95, 0xd1, 0xda,
    0x39, 0x2a, 0x0d, 0x2f, 0x8e, 0xd0, 0xc6, 0xc7, 0xbc, 0x0f, 0x4c, 0xfa, 0xc8, 0xc2, 0x80,
    0xb5, 0x6d,
];
const PYTH_RECEIVER_PROGRAM_ID: Pubkey =
    pubkey!("rec5EKMGg6MxZYaMdyBfgwp4d5rB9T1VQH5pJv5LtFJ");
const PYTH_PRICE_UPDATE_V2_DISCRIMINATOR: [u8; 8] =
    [34, 241, 35, 99, 157, 126, 244, 205];
const PYTH_MAXIMUM_AGE_SECONDS: i64 = 180;
const MICRO_USD_DECIMALS: i32 = 6;

const SECONDS_PER_DAY: i64 = 86_400;
const DIRECTION_LONG: u8 = 0;
const DIRECTION_SHORT: u8 = 1;
const WIN_SCORE: u64 = 100;
const LOSS_SCORE: u64 = 10;
const PLAY_EXP: u64 = 5;
const WIN_EXP: u64 = 20;
const LOSS_EXP: u64 = 2;
const MAX_STREAK_EXP_BONUS: u64 = 50;

#[program]
pub mod candle_clash {
    use super::*;

    pub fn initialize_config(
        ctx: Context<InitializeConfig>,
        treasury: Pubkey,
        entry_fee_lamports: u64,
        pool_fee_lamports: u64,
        treasury_fee_lamports: u64,
        round_duration_seconds: i64,
        session_duration_seconds: i64,
        max_session_spend_lamports_default: u64,
    ) -> Result<()> {
        require!(
            pool_fee_lamports
                .checked_add(treasury_fee_lamports)
                .ok_or(CandleClashError::MathOverflow)?
                <= entry_fee_lamports,
            CandleClashError::MathOverflow
        );

        let config = &mut ctx.accounts.global_config;
        config.admin = ctx.accounts.admin.key();
        config.treasury = treasury;
        config.entry_fee_lamports = entry_fee_lamports;
        config.pool_fee_lamports = pool_fee_lamports;
        config.treasury_fee_lamports = treasury_fee_lamports;
        config.round_duration_seconds = round_duration_seconds;
        config.session_duration_seconds = session_duration_seconds;
        config.max_session_spend_lamports_default = max_session_spend_lamports_default;
        config.bump = ctx.bumps.global_config;
        Ok(())
    }

    pub fn update_config(
        ctx: Context<UpdateConfig>,
        treasury: Pubkey,
        entry_fee_lamports: u64,
        pool_fee_lamports: u64,
        treasury_fee_lamports: u64,
        round_duration_seconds: i64,
        session_duration_seconds: i64,
        max_session_spend_lamports_default: u64,
    ) -> Result<()> {
        require_keys_eq!(
            ctx.accounts.admin.key(),
            ctx.accounts.global_config.admin,
            CandleClashError::Unauthorized
        );
        require!(
            pool_fee_lamports
                .checked_add(treasury_fee_lamports)
                .ok_or(CandleClashError::MathOverflow)?
                <= entry_fee_lamports,
            CandleClashError::MathOverflow
        );

        let config = &mut ctx.accounts.global_config;
        config.treasury = treasury;
        config.entry_fee_lamports = entry_fee_lamports;
        config.pool_fee_lamports = pool_fee_lamports;
        config.treasury_fee_lamports = treasury_fee_lamports;
        config.round_duration_seconds = round_duration_seconds;
        config.session_duration_seconds = session_duration_seconds;
        config.max_session_spend_lamports_default = max_session_spend_lamports_default;
        Ok(())
    }

    pub fn initialize_player(ctx: Context<InitializePlayer>) -> Result<()> {
        let now = Clock::get()?.unix_timestamp;

        let profile = &mut ctx.accounts.player_profile;
        if profile.player == Pubkey::default() {
            profile.player = ctx.accounts.player.key();
            profile.created_at = now;
            profile.bump = ctx.bumps.player_profile;
        }
        profile.updated_at = now;

        let vault = &mut ctx.accounts.player_vault;
        if vault.player == Pubkey::default() {
            vault.player = ctx.accounts.player.key();
            vault.bump = ctx.bumps.player_vault;
        }
        Ok(())
    }

    pub fn deposit(ctx: Context<Deposit>, amount: u64) -> Result<()> {
        system_program::transfer(
            CpiContext::new(
                ctx.accounts.system_program.to_account_info(),
                system_program::Transfer {
                    from: ctx.accounts.player.to_account_info(),
                    to: ctx.accounts.player_vault.to_account_info(),
                },
            ),
            amount,
        )?;

        let vault = &mut ctx.accounts.player_vault;
        vault.balance_lamports = checked_add(vault.balance_lamports, amount)?;
        vault.total_deposited_lamports = checked_add(vault.total_deposited_lamports, amount)?;
        Ok(())
    }

    pub fn withdraw(ctx: Context<Withdraw>, amount: u64) -> Result<()> {
        let vault = &mut ctx.accounts.player_vault;
        require!(
            vault.balance_lamports >= amount,
            CandleClashError::InsufficientVaultBalance
        );

        vault.balance_lamports = vault
            .balance_lamports
            .checked_sub(amount)
            .ok_or(CandleClashError::MathOverflow)?;
        vault.total_withdrawn_lamports = checked_add(vault.total_withdrawn_lamports, amount)?;

        **vault.to_account_info().try_borrow_mut_lamports()? = vault
            .to_account_info()
            .lamports()
            .checked_sub(amount)
            .ok_or(CandleClashError::MathOverflow)?;
        **ctx.accounts.player.to_account_info().try_borrow_mut_lamports()? = ctx
            .accounts
            .player
            .to_account_info()
            .lamports()
            .checked_add(amount)
            .ok_or(CandleClashError::MathOverflow)?;
        Ok(())
    }

    pub fn start_session(
        ctx: Context<StartSession>,
        session_authority: Pubkey,
        max_spend_lamports: u64,
    ) -> Result<()> {
        require!(
            max_spend_lamports <= ctx.accounts.player_vault.balance_lamports,
            CandleClashError::InsufficientVaultBalance
        );

        let now = Clock::get()?.unix_timestamp;
        let expires_at = now
            .checked_add(ctx.accounts.global_config.session_duration_seconds)
            .ok_or(CandleClashError::MathOverflow)?;

        let session = &mut ctx.accounts.player_session;
        session.player = ctx.accounts.player.key();
        session.session_authority = session_authority;
        session.expires_at = expires_at;
        session.max_spend_lamports = max_spend_lamports;
        session.spent_lamports = 0;
        session.is_active = true;
        session.bump = ctx.bumps.player_session;
        Ok(())
    }

    pub fn end_session(ctx: Context<EndSession>) -> Result<()> {
        ctx.accounts.player_session.is_active = false;
        Ok(())
    }

    pub fn start_round(
        ctx: Context<StartRound>,
        round_id: u64,
        direction: u8,
        client_day_id: u64,
    ) -> Result<()> {
        require!(
            direction == DIRECTION_LONG || direction == DIRECTION_SHORT,
            CandleClashError::InvalidDirection
        );
        require!(
            ctx.accounts.player_session.is_active,
            CandleClashError::SessionInactive
        );

        let now = Clock::get()?.unix_timestamp;
        require!(
            now < ctx.accounts.player_session.expires_at,
            CandleClashError::SessionExpired
        );

        let config = &ctx.accounts.global_config;
        let session = &mut ctx.accounts.player_session;
        let next_spend = checked_add(session.spent_lamports, config.entry_fee_lamports)?;
        require!(
            next_spend <= session.max_spend_lamports,
            CandleClashError::SessionSpendLimitExceeded
        );

        let vault = &mut ctx.accounts.player_vault;
        require!(
            vault.balance_lamports >= config.entry_fee_lamports,
            CandleClashError::InsufficientVaultBalance
        );

        let price = read_price(&ctx.accounts.price_feed.to_account_info())?;
        let day_id = day_id_from_timestamp(now)?;
        require!(client_day_id == day_id, CandleClashError::Unauthorized);

        vault.balance_lamports = vault
            .balance_lamports
            .checked_sub(config.entry_fee_lamports)
            .ok_or(CandleClashError::MathOverflow)?;
        session.spent_lamports = next_spend;

        let profile = &mut ctx.accounts.player_profile;
        profile.total_games = checked_add(profile.total_games, 1)?;
        profile.total_spent_lamports = checked_add(profile.total_spent_lamports, config.entry_fee_lamports)?;
        profile.total_pool_contributed_lamports =
            checked_add(profile.total_pool_contributed_lamports, config.pool_fee_lamports)?;
        profile.total_treasury_paid_lamports =
            checked_add(profile.total_treasury_paid_lamports, config.treasury_fee_lamports)?;
        if direction == DIRECTION_LONG {
            profile.total_long = checked_add(profile.total_long, 1)?;
        } else {
            profile.total_short = checked_add(profile.total_short, 1)?;
        }
        profile.updated_at = now;

        let daily_pool = &mut ctx.accounts.daily_pool;
        if daily_pool.created_at == 0 {
            daily_pool.day_id = day_id;
            daily_pool.created_at = now;
            daily_pool.bump = ctx.bumps.daily_pool;
        }
        daily_pool.total_pool_lamports =
            checked_add(daily_pool.total_pool_lamports, config.pool_fee_lamports)?;
        daily_pool.total_games = checked_add(daily_pool.total_games, 1)?;

        let daily_player = &mut ctx.accounts.daily_player;
        if daily_player.player == Pubkey::default() {
            daily_player.day_id = day_id;
            daily_player.player = ctx.accounts.player.key();
            daily_player.bump = ctx.bumps.daily_player;
            daily_pool.total_players = checked_add(daily_pool.total_players, 1)?;
        }
        daily_player.daily_games = checked_add(daily_player.daily_games, 1)?;
        daily_player.daily_spent_lamports =
            checked_add(daily_player.daily_spent_lamports, config.entry_fee_lamports)?;
        daily_player.daily_pool_contributed_lamports = checked_add(
            daily_player.daily_pool_contributed_lamports,
            config.pool_fee_lamports,
        )?;
        if direction == DIRECTION_LONG {
            daily_player.daily_long = checked_add(daily_player.daily_long, 1)?;
        } else {
            daily_player.daily_short = checked_add(daily_player.daily_short, 1)?;
        }
        daily_player.last_played_at = now;

        let round = &mut ctx.accounts.game_round;
        round.player = ctx.accounts.player.key();
        round.session_authority = ctx.accounts.session_authority.key();
        round.round_id = round_id;
        round.day_id = day_id;
        round.direction = direction;
        round.entry_fee_lamports = config.entry_fee_lamports;
        round.start_price = price;
        round.end_price = 0;
        round.start_time = now;
        round.end_time = now
            .checked_add(config.round_duration_seconds)
            .ok_or(CandleClashError::MathOverflow)?;
        round.settled = false;
        round.won = false;
        round.score_delta = 0;
        round.exp_delta = 0;
        round.bump = ctx.bumps.game_round;
        Ok(())
    }

    pub fn settle_round(ctx: Context<SettleRound>, _round_id: u64) -> Result<()> {
        require!(
            ctx.accounts.authority.key() == ctx.accounts.game_round.player
                || ctx.accounts.authority.key() == ctx.accounts.game_round.session_authority,
            CandleClashError::Unauthorized
        );
        require!(
            !ctx.accounts.game_round.settled,
            CandleClashError::RoundAlreadySettled
        );

        let now = Clock::get()?.unix_timestamp;
        require!(
            now >= ctx.accounts.game_round.end_time,
            CandleClashError::RoundNotReadyToSettle
        );

        let end_price = read_price(&ctx.accounts.price_feed.to_account_info())?;
        let round = &mut ctx.accounts.game_round;
        let pushed = end_price == round.start_price;
        let won = match round.direction {
            DIRECTION_LONG => end_price > round.start_price,
            DIRECTION_SHORT => end_price < round.start_price,
            _ => return err!(CandleClashError::InvalidDirection),
        };

        let profile = &mut ctx.accounts.player_profile;
        let daily_player = &mut ctx.accounts.daily_player;

        let streak_after = if won {
            checked_add(profile.current_streak, 1)?
        } else {
            0
        };
        let streak_score_bonus = if won {
            streak_after.checked_mul(10).ok_or(CandleClashError::MathOverflow)?
        } else {
            0
        };
        let score_delta = if pushed {
            0
        } else if won {
            checked_add(WIN_SCORE, streak_score_bonus)?
        } else {
            LOSS_SCORE
        };
        let streak_exp_bonus = if won {
            streak_after
                .checked_mul(2)
                .ok_or(CandleClashError::MathOverflow)?
                .min(MAX_STREAK_EXP_BONUS)
        } else {
            0
        };
        let exp_delta = if pushed {
            PLAY_EXP
        } else if won {
            checked_add(checked_add(PLAY_EXP, WIN_EXP)?, streak_exp_bonus)?
        } else {
            checked_add(PLAY_EXP, LOSS_EXP)?
        };

        if pushed {
            ctx.accounts.player_vault.balance_lamports =
                checked_add(ctx.accounts.player_vault.balance_lamports, round.entry_fee_lamports)?;
            profile.current_streak = 0;
        } else if won {
            profile.total_wins = checked_add(profile.total_wins, 1)?;
            daily_player.daily_wins = checked_add(daily_player.daily_wins, 1)?;
            profile.current_streak = streak_after;
            if profile.current_streak > profile.best_streak {
                profile.best_streak = profile.current_streak;
            }
        } else {
            profile.total_losses = checked_add(profile.total_losses, 1)?;
            daily_player.daily_losses = checked_add(daily_player.daily_losses, 1)?;
            profile.current_streak = 0;
        }
        profile.exp = checked_add(profile.exp, exp_delta)?;
        profile.level = level_from_exp(profile.exp)?;
        profile.updated_at = now;

        daily_player.daily_score = checked_add(daily_player.daily_score, score_delta)?;
        daily_player.last_played_at = now;

        round.end_price = end_price;
        round.settled = true;
        round.won = won;
        round.score_delta = score_delta;
        round.exp_delta = exp_delta;
        Ok(())
    }

    pub fn claim_daily_rewards(_ctx: Context<ClaimDailyRewards>, _day_id: u64) -> Result<()> {
        Ok(())
    }

    pub fn initialize_mock_price_feed(
        ctx: Context<InitializeMockPriceFeed>,
        price: i64,
    ) -> Result<()> {
        require!(price > 0, CandleClashError::InvalidOraclePrice);
        let feed = &mut ctx.accounts.price_feed;
        feed.admin = ctx.accounts.admin.key();
        feed.price = price;
        feed.updated_at = Clock::get()?.unix_timestamp;
        feed.bump = ctx.bumps.price_feed;
        Ok(())
    }

    pub fn set_mock_price(ctx: Context<SetMockPrice>, price: i64) -> Result<()> {
        require_keys_eq!(
            ctx.accounts.admin.key(),
            ctx.accounts.price_feed.admin,
            CandleClashError::Unauthorized
        );
        require!(price > 0, CandleClashError::InvalidOraclePrice);
        let feed = &mut ctx.accounts.price_feed;
        feed.price = price;
        feed.updated_at = Clock::get()?.unix_timestamp;
        Ok(())
    }
}

#[derive(Accounts)]
pub struct InitializeConfig<'info> {
    #[account(
        init,
        payer = admin,
        space = 8 + GlobalConfig::INIT_SPACE,
        seeds = [GLOBAL_CONFIG_SEED],
        bump
    )]
    pub global_config: Account<'info, GlobalConfig>,
    #[account(mut)]
    pub admin: Signer<'info>,
    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct UpdateConfig<'info> {
    #[account(mut, seeds = [GLOBAL_CONFIG_SEED], bump = global_config.bump)]
    pub global_config: Account<'info, GlobalConfig>,
    pub admin: Signer<'info>,
}

#[derive(Accounts)]
pub struct InitializePlayer<'info> {
    #[account(mut)]
    pub player: Signer<'info>,
    #[account(
        init_if_needed,
        payer = player,
        space = 8 + PlayerProfile::INIT_SPACE,
        seeds = [PLAYER_PROFILE_SEED, player.key().as_ref()],
        bump
    )]
    pub player_profile: Account<'info, PlayerProfile>,
    #[account(
        init_if_needed,
        payer = player,
        space = 8 + PlayerVault::INIT_SPACE,
        seeds = [PLAYER_VAULT_SEED, player.key().as_ref()],
        bump
    )]
    pub player_vault: Account<'info, PlayerVault>,
    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct Deposit<'info> {
    #[account(mut)]
    pub player: Signer<'info>,
    #[account(
        mut,
        seeds = [PLAYER_VAULT_SEED, player.key().as_ref()],
        bump = player_vault.bump,
        has_one = player
    )]
    pub player_vault: Account<'info, PlayerVault>,
    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct Withdraw<'info> {
    #[account(mut)]
    pub player: Signer<'info>,
    #[account(
        mut,
        seeds = [PLAYER_VAULT_SEED, player.key().as_ref()],
        bump = player_vault.bump,
        has_one = player
    )]
    pub player_vault: Account<'info, PlayerVault>,
}

#[derive(Accounts)]
#[instruction(session_authority: Pubkey)]
pub struct StartSession<'info> {
    pub global_config: Account<'info, GlobalConfig>,
    #[account(mut)]
    pub player: Signer<'info>,
    #[account(
        seeds = [PLAYER_VAULT_SEED, player.key().as_ref()],
        bump = player_vault.bump,
        has_one = player
    )]
    pub player_vault: Account<'info, PlayerVault>,
    #[account(
        init_if_needed,
        payer = player,
        space = 8 + PlayerSession::INIT_SPACE,
        seeds = [PLAYER_SESSION_SEED, player.key().as_ref(), session_authority.as_ref()],
        bump
    )]
    pub player_session: Account<'info, PlayerSession>,
    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct EndSession<'info> {
    pub player: Signer<'info>,
    #[account(
        mut,
        seeds = [
            PLAYER_SESSION_SEED,
            player.key().as_ref(),
            player_session.session_authority.as_ref()
        ],
        bump = player_session.bump,
        has_one = player
    )]
    pub player_session: Account<'info, PlayerSession>,
}

#[derive(Accounts)]
#[instruction(round_id: u64, direction: u8, client_day_id: u64)]
pub struct StartRound<'info> {
    pub global_config: Account<'info, GlobalConfig>,
    /// CHECK: constrained by PDA seeds on all player-owned accounts.
    pub player: UncheckedAccount<'info>,
    #[account(mut)]
    pub session_authority: Signer<'info>,
    #[account(
        mut,
        seeds = [PLAYER_PROFILE_SEED, player.key().as_ref()],
        bump = player_profile.bump,
        has_one = player
    )]
    pub player_profile: Account<'info, PlayerProfile>,
    #[account(
        mut,
        seeds = [PLAYER_VAULT_SEED, player.key().as_ref()],
        bump = player_vault.bump,
        has_one = player
    )]
    pub player_vault: Account<'info, PlayerVault>,
    #[account(
        mut,
        seeds = [PLAYER_SESSION_SEED, player.key().as_ref(), session_authority.key().as_ref()],
        bump = player_session.bump,
        has_one = player,
        has_one = session_authority
    )]
    pub player_session: Account<'info, PlayerSession>,
    #[account(
        init_if_needed,
        payer = session_authority,
        space = 8 + DailyPool::INIT_SPACE,
        seeds = [DAILY_POOL_SEED, &client_day_id.to_le_bytes()],
        bump
    )]
    pub daily_pool: Account<'info, DailyPool>,
    #[account(
        init_if_needed,
        payer = session_authority,
        space = 8 + DailyPlayer::INIT_SPACE,
        seeds = [DAILY_PLAYER_SEED, &client_day_id.to_le_bytes(), player.key().as_ref()],
        bump
    )]
    pub daily_player: Account<'info, DailyPlayer>,
    #[account(
        init,
        payer = session_authority,
        space = 8 + GameRound::INIT_SPACE,
        seeds = [GAME_ROUND_SEED, player.key().as_ref(), &round_id.to_le_bytes()],
        bump
    )]
    pub game_round: Account<'info, GameRound>,
    /// CHECK: Pyth SOL/USD sponsored feed on devnet, or local mock in tests.
    pub price_feed: UncheckedAccount<'info>,
    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
#[instruction(round_id: u64)]
pub struct SettleRound<'info> {
    pub authority: Signer<'info>,
    #[account(mut)]
    pub player_profile: Account<'info, PlayerProfile>,
    #[account(mut)]
    pub daily_player: Account<'info, DailyPlayer>,
    #[account(
        mut,
        seeds = [PLAYER_VAULT_SEED, game_round.player.as_ref()],
        bump = player_vault.bump
    )]
    pub player_vault: Account<'info, PlayerVault>,
    #[account(
        mut,
        seeds = [GAME_ROUND_SEED, game_round.player.as_ref(), &round_id.to_le_bytes()],
        bump = game_round.bump
    )]
    pub game_round: Account<'info, GameRound>,
    /// CHECK: Pyth SOL/USD sponsored feed on devnet, or local mock in tests.
    pub price_feed: UncheckedAccount<'info>,
}

#[derive(Accounts)]
pub struct ClaimDailyRewards<'info> {
    pub player: Signer<'info>,
}

#[derive(Accounts)]
pub struct InitializeMockPriceFeed<'info> {
    #[account(mut)]
    pub admin: Signer<'info>,
    #[account(
        init,
        payer = admin,
        space = 8 + MockPriceFeed::INIT_SPACE,
        seeds = [MOCK_PRICE_FEED_SEED],
        bump
    )]
    pub price_feed: Account<'info, MockPriceFeed>,
    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct SetMockPrice<'info> {
    pub admin: Signer<'info>,
    #[account(mut, seeds = [MOCK_PRICE_FEED_SEED], bump = price_feed.bump)]
    pub price_feed: Account<'info, MockPriceFeed>,
}

#[account]
#[derive(InitSpace)]
pub struct GlobalConfig {
    pub admin: Pubkey,
    pub treasury: Pubkey,
    pub entry_fee_lamports: u64,
    pub pool_fee_lamports: u64,
    pub treasury_fee_lamports: u64,
    pub round_duration_seconds: i64,
    pub session_duration_seconds: i64,
    pub max_session_spend_lamports_default: u64,
    pub bump: u8,
}

#[account]
#[derive(InitSpace)]
pub struct PlayerProfile {
    pub player: Pubkey,
    pub total_games: u64,
    pub total_wins: u64,
    pub total_losses: u64,
    pub total_long: u64,
    pub total_short: u64,
    pub total_spent_lamports: u64,
    pub total_pool_contributed_lamports: u64,
    pub total_treasury_paid_lamports: u64,
    pub exp: u64,
    pub level: u64,
    pub current_streak: u64,
    pub best_streak: u64,
    pub created_at: i64,
    pub updated_at: i64,
    pub bump: u8,
}

#[account]
#[derive(InitSpace)]
pub struct PlayerVault {
    pub player: Pubkey,
    pub balance_lamports: u64,
    pub total_deposited_lamports: u64,
    pub total_withdrawn_lamports: u64,
    pub bump: u8,
}

#[account]
#[derive(InitSpace)]
pub struct PlayerSession {
    pub player: Pubkey,
    pub session_authority: Pubkey,
    pub expires_at: i64,
    pub max_spend_lamports: u64,
    pub spent_lamports: u64,
    pub is_active: bool,
    pub bump: u8,
}

#[account]
#[derive(InitSpace)]
pub struct DailyPool {
    pub day_id: u64,
    pub total_pool_lamports: u64,
    pub total_games: u64,
    pub total_players: u64,
    pub distributed: bool,
    pub created_at: i64,
    pub bump: u8,
}

#[account]
#[derive(InitSpace)]
pub struct DailyPlayer {
    pub day_id: u64,
    pub player: Pubkey,
    pub daily_score: u64,
    pub daily_games: u64,
    pub daily_wins: u64,
    pub daily_losses: u64,
    pub daily_long: u64,
    pub daily_short: u64,
    pub daily_spent_lamports: u64,
    pub daily_pool_contributed_lamports: u64,
    pub last_played_at: i64,
    pub bump: u8,
}

#[account]
#[derive(InitSpace)]
pub struct GameRound {
    pub player: Pubkey,
    pub session_authority: Pubkey,
    pub round_id: u64,
    pub day_id: u64,
    pub direction: u8,
    pub entry_fee_lamports: u64,
    pub start_price: i64,
    pub end_price: i64,
    pub start_time: i64,
    pub end_time: i64,
    pub settled: bool,
    pub won: bool,
    pub score_delta: u64,
    pub exp_delta: u64,
    pub bump: u8,
}

#[account]
#[derive(InitSpace)]
pub struct MockPriceFeed {
    pub admin: Pubkey,
    pub price: i64,
    pub updated_at: i64,
    pub bump: u8,
}

#[error_code]
pub enum CandleClashError {
    #[msg("The player vault does not have enough internal balance.")]
    InsufficientVaultBalance,
    #[msg("The delegated session has expired.")]
    SessionExpired,
    #[msg("The delegated session is inactive.")]
    SessionInactive,
    #[msg("The delegated session spend limit would be exceeded.")]
    SessionSpendLimitExceeded,
    #[msg("Direction must be 0 for long or 1 for short.")]
    InvalidDirection,
    #[msg("This round is already settled.")]
    RoundAlreadySettled,
    #[msg("This round is not ready to settle yet.")]
    RoundNotReadyToSettle,
    #[msg("Oracle price is invalid.")]
    InvalidOraclePrice,
    #[msg("The signer is not authorized for this action.")]
    Unauthorized,
    #[msg("A checked math operation overflowed.")]
    MathOverflow,
}

fn read_price(feed: &AccountInfo) -> Result<i64> {
    if feed.owner == &crate::ID {
        return read_mock_price(feed);
    }
    read_pyth_price(feed)
}

fn read_mock_price(feed: &AccountInfo) -> Result<i64> {
    let data = feed.try_borrow_data()?;
    require!(data.len() >= 48, CandleClashError::InvalidOraclePrice);
    let price = read_i64(&data, 40)?;
    require!(price > 0, CandleClashError::InvalidOraclePrice);
    Ok(price)
}

fn read_pyth_price(feed: &AccountInfo) -> Result<i64> {
    require_keys_eq!(feed.key(), PYTH_SOL_USD_PRICE_FEED, CandleClashError::InvalidOraclePrice);
    require_keys_eq!(
        *feed.owner,
        PYTH_RECEIVER_PROGRAM_ID,
        CandleClashError::InvalidOraclePrice
    );

    let data = feed.try_borrow_data()?;
    require!(data.len() >= 133, CandleClashError::InvalidOraclePrice);
    require!(
        data[0..8] == PYTH_PRICE_UPDATE_V2_DISCRIMINATOR,
        CandleClashError::InvalidOraclePrice
    );

    let mut offset = 8 + 32;
    let verification_tag = data[offset];
    offset += 1;
    if verification_tag == 0 {
        require!(data.len() >= 134, CandleClashError::InvalidOraclePrice);
        offset += 1;
    } else {
        require!(verification_tag == 1, CandleClashError::InvalidOraclePrice);
    }

    require!(
        data[offset..offset + 32] == PYTH_SOL_USD_FEED_ID,
        CandleClashError::InvalidOraclePrice
    );
    offset += 32;

    let price = read_i64(&data, offset)?;
    offset += 8;
    let _conf = read_u64(&data, offset)?;
    offset += 8;
    let exponent = read_i32(&data, offset)?;
    offset += 4;
    let publish_time = read_i64(&data, offset)?;

    let now = Clock::get()?.unix_timestamp;
    require!(
        publish_time
            .checked_add(PYTH_MAXIMUM_AGE_SECONDS)
            .ok_or(CandleClashError::MathOverflow)?
            >= now,
        CandleClashError::InvalidOraclePrice
    );
    normalize_pyth_price_to_micro_usd(price, exponent)
}

fn normalize_pyth_price_to_micro_usd(price: i64, exponent: i32) -> Result<i64> {
    require!(price > 0, CandleClashError::InvalidOraclePrice);
    let scale_exponent = MICRO_USD_DECIMALS
        .checked_add(exponent)
        .ok_or(CandleClashError::MathOverflow)?;
    if scale_exponent >= 0 {
        let multiplier = 10_i64
            .checked_pow(scale_exponent as u32)
            .ok_or(CandleClashError::MathOverflow)?;
        price.checked_mul(multiplier).ok_or(CandleClashError::MathOverflow.into())
    } else {
        let divisor = 10_i64
            .checked_pow((-scale_exponent) as u32)
            .ok_or(CandleClashError::MathOverflow)?;
        Ok(price / divisor)
    }
}

fn read_i64(data: &[u8], offset: usize) -> Result<i64> {
    let bytes: [u8; 8] = data
        .get(offset..offset + 8)
        .ok_or(CandleClashError::InvalidOraclePrice)?
        .try_into()
        .map_err(|_| CandleClashError::InvalidOraclePrice)?;
    Ok(i64::from_le_bytes(bytes))
}

fn read_i32(data: &[u8], offset: usize) -> Result<i32> {
    let bytes: [u8; 4] = data
        .get(offset..offset + 4)
        .ok_or(CandleClashError::InvalidOraclePrice)?
        .try_into()
        .map_err(|_| CandleClashError::InvalidOraclePrice)?;
    Ok(i32::from_le_bytes(bytes))
}

fn read_u64(data: &[u8], offset: usize) -> Result<u64> {
    let bytes: [u8; 8] = data
        .get(offset..offset + 8)
        .ok_or(CandleClashError::InvalidOraclePrice)?
        .try_into()
        .map_err(|_| CandleClashError::InvalidOraclePrice)?;
    Ok(u64::from_le_bytes(bytes))
}

fn checked_add(left: u64, right: u64) -> Result<u64> {
    left.checked_add(right).ok_or(CandleClashError::MathOverflow.into())
}

fn day_id_from_timestamp(timestamp: i64) -> Result<u64> {
    require!(timestamp >= 0, CandleClashError::MathOverflow);
    Ok((timestamp / SECONDS_PER_DAY) as u64)
}

fn level_from_exp(exp: u64) -> Result<u64> {
    let base = exp / 100;
    checked_add(integer_sqrt(base), 1)
}

fn integer_sqrt(value: u64) -> u64 {
    if value < 2 {
        return value;
    }

    let mut left = 1_u64;
    let mut right = value.min(1 << 32);
    let mut answer = 1_u64;
    while left <= right {
        let mid = left + ((right - left) / 2);
        if mid <= value / mid {
            answer = mid;
            left = mid + 1;
        } else {
            right = mid - 1;
        }
    }
    answer
}
