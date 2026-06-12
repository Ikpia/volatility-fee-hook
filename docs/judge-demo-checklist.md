# Judge Demo Checklist

1. Show the initialized Uniswap v4 pool using `LPFeeLibrary.DYNAMIC_FEE_FLAG`.
2. Show the initial low fee in `volatilityState`.
3. Run stable swaps and show `SwapPriceUpdate` events.
4. Run volatile swaps and show larger sqrt price moves.
5. Show Lasna subscription status and RVM processing.
6. Show the queued callback evidence when the RSC callback event is visible.
7. Show destination `FeeUpdated` from the callback proxy path.
8. Re-run `currentFee` and show the next swap reads the updated fee.

Do not describe a subscription transaction as a callback transaction. They prove different layers.
