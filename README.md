# VolatilityFee Hook

Pool fees that price volatility risk correctly.

VolatilityFee Hook is a Uniswap v4 dynamic-fee hook powered by Reactive Network. The hook keeps the swap path cheap: `beforeSwap` only reads the currently active fee from storage and returns it with Uniswap v4's override flag. All realized-volatility math happens off the swap path in a Reactive Smart Contract on Lasna.

## Why It Exists

Static fee tiers are wrong for volatile pairs. When prices move sharply, LPs need higher fees to compensate for impermanent-loss and arbitrage risk. When markets are calm, high fees become deadweight spread and push order flow elsewhere.

This project uses realized volatility instead:

```text
r_i = |sqrtPriceX96_i - sqrtPriceX96_{i-1}| / sqrtPriceX96_{i-1}
EWMA_i = 0.10 * r_i + 0.90 * EWMA_{i-1}
```

| EWMA volatility | Fee |
| --- | ---: |
| `< 0.10%` | 500, 5 bps |
| `0.10% - 0.50%` | 3000, 30 bps |
| `>= 0.50%` | 10000, 100 bps |

## Architecture

```text
Swapper -> PoolManager -> VolatilityFeeHook.beforeSwap()
                              |
                              | reads currentFee
                              v
                         swap executes
                              |
                              v
VolatilityFeeHook.afterSwap() emits SwapPriceUpdate(poolId, sqrtPriceX96, timestamp)
                              |
                              v
Reactive Lasna RSC computes EWMA and maps fee tier
                              |
                              v
Reactive callback proxy -> VolatilityFeeHook.updateFeeFromReactive(sender, poolId, fee)
```

The destination hook validates both callback layers:

- `msg.sender == callbackProxy`
- encoded `sender == reactiveSender`

If Reactive is unavailable, the pool keeps using the last stored fee. It degrades to a fixed-fee pool instead of breaking swaps.

## Contracts

- `src/VolatilityFeeHook.sol` - Uniswap v4 hook with `afterInitialize`, `beforeSwap`, and `afterSwap`.
- `src/rsc/VolatilityFeeRSC.sol` - Reactive Lasna contract that subscribes to `SwapPriceUpdate` and emits callbacks.
- `src/interfaces/IVolatilityFeeHook.sol` - external interface.

## Reactive Lasna

This repo uses the legacy Reactive endpoint/library requested for the project:

| Field | Value |
| --- | --- |
| RPC URL | `https://lasna-rpc.rnk.dev/` |
| Chain ID | `5318007` |
| Currency | `lREACT` |
| System contract | `0x0000000000000000000000000000000000fffFfF` |
| Library | `Reactive-Network/reactive-lib` |

## Uniswap v4 Testnet Addresses

The `.env` includes the current v4 testnet deployment addresses used by scripts:

| Network | PoolManager | Universal Router |
| --- | --- | --- |
| Sepolia | `0xE03A1074c86CFeDd5C142C4F04F1a1536e203543` | `0x3A9D48AB9751398BbFa63ad67599Bb04e4BdF98b` |
| Base Sepolia | `0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408` | `0x492E6456D9528771018DeB9E87ef7750EF184104` |
| Unichain Sepolia | `0x00B036B58a818B1BC34d502D3fE730Db729e62AC` | `0xf70536B3bcC1bD1a972dc186A2cf84cC6da6Be5D` |

Note: the address originally supplied for “Sepolia PoolManager” is the Sepolia Universal Router. Scripts use the PoolManager address above for hook deployment.

## Build

```bash
forge build
forge test
```

Current local result: `31 passed; 0 failed`.

Production source coverage:

- `src/VolatilityFeeHook.sol`: 100% lines/statements/branches/functions
- `src/rsc/VolatilityFeeRSC.sol`: 100% lines/statements/branches/functions

## Deploy

Set the destination network values, then deploy the hook:

```bash
source .env
export POOL_MANAGER="$BASE_SEPOLIA_POOL_MANAGER"
export CALLBACK_PROXY="<reactive callback proxy>"
export REACTIVE_SENDER="<rsc callback sender or deployer>"

forge script script/Deploy.s.sol:DeployVolatilityFeeHook \
  --rpc-url "$BASE_SEPOLIA_RPC_URL" \
  --broadcast
```

Deploy the Reactive Smart Contract on Lasna:

```bash
export DESTINATION_CHAIN_ID=84532
export VOLATILITY_FEE_HOOK="<deployed hook>"

forge script script/DeployRSC.s.sol:DeployVolatilityFeeRSC \
  --rpc-url "$LASNA_RPC_URL" \
  --broadcast
```

## Dynamic-Fee Pool Requirement

The v4 pool must be initialized with:

```solidity
fee: LPFeeLibrary.DYNAMIC_FEE_FLAG
```

Without the dynamic-fee flag, `beforeSwap` fee overrides are ignored by v4.

## E2E Runner

```bash
./script/demo-with-txids.sh
```

The runner builds, tests, prints deployment readbacks, labels the Reactive proof phases, and appends a demo ledger to `docs/e2e.md`. Once deployed addresses are set in `.env`, it prints clickable explorer URLs.

## Frontend

Open:

```text
frontend/index.html
```

The judge UI lets users simulate calm, spike, and recovery price paths and watch the fee tier change through the same EWMA math used by the RSC.
