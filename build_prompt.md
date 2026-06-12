# Build Prompt: VolatilityFee Hook

You are building VolatilityFee Hook to production quality inside this repository.

## First Read

Before coding, read:

1. `README.md`
2. `SPEC.md`
3. `context/README.md`
4. Reactive docs under `context/reactive-network/`
5. Uniswap docs under `context/uniswap-docs/`
6. UHI workshop examples under `context/uhi-workshops/`
7. Current contracts under `src/`
8. Current tests under `test/`
9. Current scripts under `script/`

Do not skip the context pass. Extract patterns for:

- Uniswap v4 hook permissions and HookMiner deployment
- dynamic-fee pool initialization with `LPFeeLibrary.DYNAMIC_FEE_FLAG`
- Reactive legacy Lasna subscription behavior
- callback proof phases and txid logging
- local demo UX expectations

## Target

Build the hook project to production readiness:

- Solidity contracts compile against real Uniswap v4 and Reactive libraries.
- Hook address mining is used for deployment.
- Reactive callback auth uses both callback proxy and encoded RSC sender.
- `beforeSwap` is cheap and only returns the current dynamic fee override.
- RSC computes EWMA off-path and only emits callbacks when the tier changes.
- No return-delta hooks are enabled.
- README and SPEC remain accurate.

## Required Deliverables

1. Contracts
   - `src/VolatilityFeeHook.sol`
   - `src/rsc/VolatilityFeeRSC.sol`
   - interfaces and test harnesses as needed

2. Tests
   - unit tests for hook permissions, initialization, swap fee reads, event emission, and access control
   - unit tests for EWMA math and fee mapping boundaries
   - fuzz tests for price sequences and overflow resistance
   - integration-style tests that simulate RSC callback throttling and fee transitions
   - fork tests when RPC endpoints and deployed testnet pools are available

3. Scripts
   - hook address mining
   - destination hook deployment
   - Lasna RSC deployment/subscription
   - e2e runner that prints labeled txids and clickable explorer URLs
   - demo script covering calm swaps, volatility spike, and recovery

4. Frontend
   - judge-facing UI in `frontend/`
   - visible EWMA and fee tier state
   - controls for calm, spike, and recovery market paths
   - deployment address inputs
   - txid ledger copy action

5. Verification
   - `forge build`
   - `forge test`
   - coverage report where practical
   - e2e script dry run
   - frontend opened or built and visually checked

## Reactive Integration Rules

Treat Reactive as a two-chain system with three proof layers:

1. destination chain origin event
2. Lasna / ReactVM reaction
3. destination chain callback

Do not treat an origin event as proof of callback completion. The e2e logs must distinguish:

- RSC deploy tx
- subscription tx
- origin event tx
- Lasna RVM tx
- destination callback tx

Use Lasna legacy config:

- RPC: `https://lasna-rpc.rnk.dev/`
- Chain ID: `5318007`
- system contract: `0x0000000000000000000000000000000000fffFfF`
- library: `Reactive-Network/reactive-lib`

If MCP/RNK calls time out, do not retry blindly. Record timeout and fall back to explorer/manual checklist.

## Production Checks

- Confirm `VOLATILITY_FEE_HOOK` address bits match enabled permissions.
- Confirm pool fee is `LPFeeLibrary.DYNAMIC_FEE_FLAG`.
- Confirm `callbackProxy` and `reactiveSender` are correct.
- Confirm `callbackDebt()` is zero before live demos if using a Reactive callback proxy that charges destination callbacks.
- Confirm the RSC subscription topic is `keccak256("SwapPriceUpdate(bytes32,uint160,uint256)")`.
- Confirm fee updates never accept arbitrary fee values.

## Current Acceptance Bar

The repository is acceptable only when:

- contracts compile cleanly
- all tests pass
- the e2e runner explains the proof phases
- the frontend can be opened by judges
- docs explain setup, limitations, and demo flow
