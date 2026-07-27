# Variational Pro — Smart Contracts

Foundry project for the Variational Pro perpetuals protocol, organized by domain.

## Contracts

**`src/core/`** — trading engine and its supporting infrastructure
- `VariationalPro.sol` — Core perps trading: open/close positions, margin, liquidation, funding
- `RFQAggregator.sol` — Aggregates quotes from Binance/OKX/Uniswap/Bybit/Kraken, returns best price
- `PriceOracle.sol` — Median-of-reporters mark price feed with a rolling TWAP
- `InsuranceFund.sol` — Share-accounted backstop vault for socialized losses

**`src/token/`**
- `VARToken.sol` — ERC-20 governance/utility token with mint cap and burn

**`src/referrals/`**
- `ReferralRegistry.sol` — Referral codes, tiered revenue share, reward claims

**`src/rewards/`**
- `PointsDistributor.sol` — Off-chain-scored points, redeemable for $VAR at an owner-set rate

**`src/utils/`**
- `Multicall.sol` — Batched read calls (`aggregate` / `tryAggregate`)

**`src/staking/`**
- `VARStaking.sol` — Lock-tiered staking ("Earn"): boosted rewards + governance voting power

**`src/governance/`**
- `VariationalGovernor.sol` — On-chain propose/vote/queue/execute, quorum-gated
- `VariationalTimelock.sol` — Execution delay for passed proposals

**`src/vesting/`**
- `VestingVault.sol` — Linear vesting with an optional cliff for team/investor allocations

**`src/libraries/`**
- `PositionMath.sol` — PnL and liquidation price math

**`src/interfaces/`** — one interface per contract above (`IVariationalPro`, `IRFQAggregator`,
`IPriceOracle`, `IInsuranceFund`, `IReferralRegistry`, `IPointsDistributor`, `IVARToken`,
`IVARStaking`, `IVariationalGovernor`)

## Setup
```bash
forge install foundry-rs/forge-std --no-git
forge install OpenZeppelin/openzeppelin-contracts --no-git
forge build
forge test -vvv
```

Note: `--no-git` only controls whether these dependencies are tracked as
git submodules in this repo — Foundry still uses `git clone` internally to
actually fetch them, so a working `git` is required either way.

## Deploy
```bash
cp .env.example .env   # fill in your values
forge script script/deploy/Deploy.s.sol --rpc-url arbitrum --broadcast --verify
```

## Test coverage
```bash
forge coverage
```
