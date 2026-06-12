# Reactive Relay Proof Checklist

Use this checklist before claiming a full live Reactive relay.

1. Confirm the hook emits `SwapPriceUpdate` on the origin chain.
2. Confirm `rnk_getFilters` includes the hook address, origin chain id, topic0, active config, and the expected RVM address.
3. Confirm `rnk_getVm` recognizes the RVM sender.
4. Poll the tail of `rnk_getTransactions` for new RVM executions after the origin event.
5. Confirm the RSC emits a `Callback` event with `updateFeeFromReactive(address,bytes32,uint24)` payload.
6. Confirm the destination chain receives a callback proxy transaction.
7. Confirm the hook emits `FeeUpdated` from the callback path, not from a direct simulation.

If any layer is missing, label the demo at the exact proof boundary reached.
