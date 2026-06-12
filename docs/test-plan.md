# Test Plan

The project test suite covers the hook, fee math, RSC callback payloads, and demo integration assumptions.

## Local

- `forge test --summary`
- `forge test --match-contract VolatilityFeeHookTest -vvv`
- `forge test --match-contract CallbackRSCTest -vvv`

## Fuzz And Stress

- Fee tier boundaries are fuzzed around the low and high volatility thresholds.
- EWMA updates are stress tested across long swap sequences.
- Callback authorization is tested for direct callers, callback proxy callers, and spoofed RVM senders.

## Live Demo Proof

Run `script/demo-with-txids.sh` after deployment. The script prints origin transactions, Lasna/RVM state, callback debt state, and destination `FeeUpdated` evidence when available.
