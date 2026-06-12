# VolatilityFee Hook Technical Specification

## Summary

VolatilityFee Hook is a Uniswap v4 dynamic-fee hook that adjusts LP fees from realized pool volatility. A Reactive Smart Contract observes post-swap price updates, computes EWMA volatility off the swap path, and pushes fee tier updates back to the hook through Reactive callbacks.

The hook targets the Reactive Network Sponsor Prize and the Uniswap General Prize for UHI9 Hookathon.

## Goals

- Keep `beforeSwap` cheap: one state read and a dynamic fee override.
- Avoid oracles, keepers, and ZK proving latency.
- Use Reactive Lasna to maintain volatility state between swaps.
- Demonstrate a complete three-phase proof: origin event, Lasna reaction, destination callback.
- Ship with unit, fuzz, integration-style callback tests, scripts, and judge frontend.

## Non-Goals

- The hook does not custody swap proceeds.
- The hook does not implement custom accounting or return deltas.
- The hook does not compute volatility inside `beforeSwap`.

## Components

### VolatilityFeeHook

Permissions:

| Hook | Enabled | Purpose |
| --- | --- | --- |
| `afterInitialize` | yes | initialize pool state at low fee |
| `beforeSwap` | yes | return current dynamic fee |
| `afterSwap` | yes | emit `SwapPriceUpdate` |
| return-delta hooks | no | avoid custom-accounting risk |

State:

```solidity
struct VolatilityState {
    uint24 currentFee;
    uint160 lastSqrtPrice;
    uint256 lastUpdateBlock;
    uint256 swapCount;
}
```

Events:

```solidity
event SwapPriceUpdate(PoolId indexed poolId, uint160 sqrtPriceX96, uint256 blockTimestamp);
event FeeUpdated(PoolId indexed poolId, uint24 oldFee, uint24 newFee, uint256 blockNumber);
```

Callback auth:

```solidity
function updateFeeFromReactive(address sender, bytes32 poolId, uint24 newFee) external;
```

The function requires:

- `msg.sender == callbackProxy`
- `sender == reactiveSender`
- `newFee` is exactly low, medium, or high tier

### VolatilityFeeRSC

The RSC subscribes to:

```text
SwapPriceUpdate(bytes32,uint160,uint256)
```

It stores EWMA state per `poolId`, throttles updates by `MIN_SWAPS_BEFORE_UPDATE`, and emits a Reactive `Callback` only when the mapped fee tier changes.

## Math

```text
return_i = |sqrtPriceX96_i - sqrtPriceX96_{i-1}| / sqrtPriceX96_{i-1}
ewma_i = alpha * return_i + (1 - alpha) * ewma_{i-1}
alpha = 0.10
```

Default tier mapping:

| Tier | Raw v4 fee | Meaning |
| --- | ---: | --- |
| Low | `500` | calm market, 5 bps |
| Medium | `3000` | normal volatility, 30 bps |
| High | `10000` | high volatility, 100 bps |

Thresholds are scaled by `1e18`:

- `VOL_THRESHOLD_LOW = 1e15`
- `VOL_THRESHOLD_HIGH = 5e15`

## Data Flow

1. User swaps through PoolManager.
2. PoolManager calls `beforeSwap`.
3. Hook returns `currentFee | LPFeeLibrary.OVERRIDE_FEE_FLAG`.
4. Swap executes.
5. PoolManager calls `afterSwap`.
6. Hook reads `sqrtPriceX96` from `StateLibrary.getSlot0`.
7. Hook emits `SwapPriceUpdate`.
8. Lasna RSC receives the log.
9. RSC computes EWMA and maps to a tier.
10. RSC emits a Reactive `Callback` if the tier changed after the minimum swap interval.
11. Reactive callback proxy calls the hook on the destination chain.
12. Hook updates `currentFee`.
13. The next swap uses the new fee.

## Deployment

Hook addresses must be mined so the low 14 bits include:

```solidity
Hooks.AFTER_INITIALIZE_FLAG | Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG
```

The deployment script uses `HookMiner.find`.

Pool initialization must use:

```solidity
LPFeeLibrary.DYNAMIC_FEE_FLAG
```

## Testing

Implemented tests:

- `VolatilityFeeHook.t.sol`
  - initial fee
  - hook permissions
  - dynamic fee override
  - post-swap event emission
  - RSC access control
  - invalid tier rejection
  - fee read after update
- `EWMAMath.t.sol`
  - first observation
  - spike and decay
  - stable-price decay
  - fuzzed bounded updates
- `FeeMapping.t.sol`
  - low, medium, high, and exact boundaries
- `RSCCallback.t.sol`
  - throttling
  - unchanged tier suppression
  - spike then recovery callback path

## Demo Proof Checklist

The live demo should print:

- Lasna RSC deploy tx
- Lasna subscription/config tx
- destination swap tx emitting `SwapPriceUpdate`
- Lasna RVM tx queueing `Callback`
- destination callback tx emitting `FeeUpdated`

The script labels these phases and appends a run ledger to `docs/e2e.md`.

## Limitations

- Reactive is event-driven, not scheduled. A new swap/event is needed to trigger fresh computation.
- If Reactive callbacks stall, the hook keeps the last fee.
- The thresholds are initial defaults and should be calibrated per pool.
- Single-block visibility of fee callback transactions can create minor routing/sandwich considerations, mitigated by tiered fees and throttling.
