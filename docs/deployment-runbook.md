# Deployment Runbook

1. Mine the hook address with the `afterInitialize`, `beforeSwap`, and `afterSwap` flags.
2. Deploy `VolatilityFeeHook` with the PoolManager, callback proxy, and expected RVM sender.
3. Deploy the demo ERC20 pair and initialize the pool with the dynamic fee flag.
4. Deploy `VolatilityFeeRSC` or `VolatilityFeeCallbackRSC` on Lasna.
5. Call `configureSubscription()` directly and verify the Lasna `Subscribe` receipt.
6. Check `rnk_getFilters` for an active filter before running swaps.
7. Fund callback debt if required by the destination callback proxy path.
8. Run `script/demo-with-txids.sh` and capture every printed explorer URL.

Keep `.env` local. Never commit private keys, API keys, or funded demo-wallet material.
