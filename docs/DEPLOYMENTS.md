# VolatilityFee Hook Deployments

Generated on 2026-06-09.

## Destination Hooks

| Network | Chain ID | Hook | Deploy tx |
| --- | ---: | --- | --- |
| Base Sepolia | `84532` | `0x8d0448Ee573dCF1f266912d5396491CF83E250C0` | https://sepolia.basescan.org/tx/0x9aa022012a53c5fc78e289ea3b95e93e461ebdae121c7bac167998633e8c3e45 |
| Ethereum Sepolia | `11155111` | `0x9427c501583FA03C9db9497F83F9558a7F7F10c0` | https://sepolia.etherscan.io/tx/0x10196c06e79e3a7d6065e0751460b7ad184f39c9257335f8e65a1636524de2eb |

Deployment config:

- Callback proxy: `0x0000000000000000000000000000000000fffFfF`
- Reactive sender/direct simulation sender: deployer address
- Fee tiers: `500`, `3000`, `10000`
- Volatility thresholds: `1e15`, `5e15`

## Reactive Lasna

| Target destination | RSC | Deploy tx | Status |
| --- | --- | --- | --- |
| Base Sepolia | `0x6E578c226fC1E3b64402982a4680FF19e373D390` | https://lasna.reactscan.net/tx/0x917df2a51d6c8a2a65ad694f8a488dc729b863cfef9229ab527345459d65ebc2 | Mined; code present; `subscriptionConfigured() == true`. |

Previous stuck tx: https://lasna.reactscan.net/tx/0x6d32086a9f1a86aa3de30a3fb857927175d1836bac190dd47fa59e513d4dbeeb.

Explicit post-deploy subscription tx:

- https://lasna.reactscan.net/tx/0x36aa5ee4ef08a62ffb8f79bac4924d9186a5cf7264d6cd66219c0499fcb33c42
- The receipt emitted the Reactive system subscription log for chain `84532`, hook `0x8d0448Ee573dCF1f266912d5396491CF83E250C0`, topic `0x2bddfc14257b1461773e94f67911c213ccc240975440fd992cda47ae43536f43`, and RSC `0x6E578c226fC1E3b64402982a4680FF19e373D390`.

## E2E Runner

Base Sepolia real demo pool:

- PoolId: `0x74f73ffa3a36fcbec277e7bed0cfb0bb2f5e3f651975cd75b7ef5a8198d72c9a`
- Token0: `0xDFC95eD456bD698193758FFe85454584a63B7c2A`
- Token1: `0xEf9C42929f5Bf12Cc368468bBdE92C741c86098d`
- Initialize tx: https://sepolia.basescan.org/tx/0xf877a4d54654d4ea9b99ba5921b28ab2cac828ece0827f43946735f543f984a2
- Liquidity tx: https://sepolia.basescan.org/tx/0x11ee157a23628dd3b992666e860d396117c3bfbca0245c312cff871efc2a2ce6
- SwapPriceUpdate tx 1: https://sepolia.basescan.org/tx/0x12039347011c3c8503bbaa63cdc5256b517f545045d87cb29282e01480b4c10a
- SwapPriceUpdate tx 2: https://sepolia.basescan.org/tx/0xe127208f6cfea30611df2d90fb6b729cdb06fa06cb4787c390b9e5414e64a24f

Post-subscription live swaps:

- Approve token0: https://sepolia.basescan.org/tx/0x59af8661f36312b1b4f31268334b21a24e65b8859374365473cb740b901f099d
- Approve token1: https://sepolia.basescan.org/tx/0x519e39e108fed720c9feb389b4dd8921c912db9e1b20e3021ca5c3c1faabd594
- SwapPriceUpdate tx 3: https://sepolia.basescan.org/tx/0xd0239219717963481223636f424a003606321c83752ff0cebb0b609aeefa0539
- SwapPriceUpdate tx 4: https://sepolia.basescan.org/tx/0x57d08ec16d74034fdab2092115bb65627dfaa02f5576d57e975571baf4c48305
- SwapPriceUpdate tx 5: https://sepolia.basescan.org/tx/0x0cdc78ad2185e91e27076f6065ab74f74b2adbbb0b54d669403745e0f6ef27b2
- Hook state after live swaps: `swapCount == 5`
- RNK filter: active for chain `84532`, hook `0x8d0448Ee573dCF1f266912d5396491CF83E250C0`, topic `0x2bddfc14257b1461773e94f67911c213ccc240975440fd992cda47ae43536f43`, RSC `0x6E578c226fC1E3b64402982a4680FF19e373D390`, RVM `0x4b992F2Fbf714C0fCBb23baC5130Ace48CaD00cd`.

Post-explicit-subscription live swaps:

- Approve token0: https://sepolia.basescan.org/tx/0x444d3eb6f5e8e0f3d67cf5951c94cfe3cc2f253a66dc73872e77756849d1a5a8
- Approve token1: https://sepolia.basescan.org/tx/0xbbae3a4f44f89b7a299a551ffd20f56d8d0edf3acbe1780310bf497fb8b684be
- SwapPriceUpdate tx 6: https://sepolia.basescan.org/tx/0xe7785d80959d48452e2ec16f142b18cc444ab33aef7e7eda48bcf58088e563d5
- SwapPriceUpdate tx 7: https://sepolia.basescan.org/tx/0x2ef3c6c3d0f7235e3088f2ad589125738129e36770af286a8455703a1479881c
- SwapPriceUpdate tx 8: https://sepolia.basescan.org/tx/0xa425e712e9ca7ce12bf4d5d2e51d075f04860ba5e14a0a910edcb4dfab230183
- Hook state after these swaps: `swapCount == 8`

RNK RVM processing proof:

- RVM `0x651`: https://lasna.reactscan.net/tx/0xabe952a26b828c70442edaca808664bcf781b632a84183c4331c8a7a5df9a248
  - Ref origin: https://sepolia.basescan.org/tx/0xd0239219717963481223636f424a003606321c83752ff0cebb0b609aeefa0539
  - Status: `1`
- RVM `0x652`: https://lasna.reactscan.net/tx/0x10644da2e91415bb7eae457ec5ec0ba79aaf3552249e4ed3e383166ce10dbaed
  - Ref origin: https://sepolia.basescan.org/tx/0x57d08ec16d74034fdab2092115bb65627dfaa02f5576d57e975571baf4c48305
  - Status: `1`
- RVM `0x653`: https://lasna.reactscan.net/tx/0x175532fe52a0643c77fb6429cebbd801018883a8157c59c39c5b08f62c83a92c
  - Ref origin: https://sepolia.basescan.org/tx/0x0cdc78ad2185e91e27076f6065ab74f74b2adbbb0b54d669403745e0f6ef27b2
  - Status: `1`
- RVM `0x654`: https://lasna.reactscan.net/tx/0x8025c02e20c4c2cdf8c16094d89d76e9d14c01a7779be9f8d56b7e52463ebaff
  - Ref origin: https://sepolia.basescan.org/tx/0xe7785d80959d48452e2ec16f142b18cc444ab33aef7e7eda48bcf58088e563d5
  - Status: `1`
- RVM `0x655`: https://lasna.reactscan.net/tx/0xef515748e2c072c793c1d2da1b0b08f9decf5f8c1c951a9f989c9ca48f09e7fb
  - Ref origin: https://sepolia.basescan.org/tx/0x2ef3c6c3d0f7235e3088f2ad589125738129e36770af286a8455703a1479881c
  - Status: `1`
- RVM `0x656`: https://lasna.reactscan.net/tx/0x6fff08654f34b1e06198374b7bd0bf3fa3ae703a112a126dd00d21223f98aa1c
  - Ref origin: https://sepolia.basescan.org/tx/0xa425e712e9ca7ce12bf4d5d2e51d075f04860ba5e14a0a910edcb4dfab230183
  - Status: `1`

Latest high-notional live swaps:

- SwapPriceUpdate: https://sepolia.basescan.org/tx/0x310d117e30972e6b61074d3e3507909309c00d9afd5082a0bda3ee5e6cbf03ad
- SwapPriceUpdate: https://sepolia.basescan.org/tx/0x81cb80fa505256412684a77c617952e2542a50497c81fd26e423680f97ae47aa
- SwapPriceUpdate: https://sepolia.basescan.org/tx/0x708b69b7e30ab694d53d014e7b9214d2ef685e28c2f512de284ca9b637dd0165
- Search result: no `FeeUpdated(bytes32,uint24,uint24,uint256)` log was found on the hook in blocks `42653975..42653984`.
- RNK tail remained at `lastTxNumber == 0x656` after this run at the time checked.

Base Sepolia direct reactive-sender simulation:

- Tx: https://sepolia.basescan.org/tx/0xe5980b2c900912f87b4cd5257cdff5e940398c116e8cf27dbaac6280c4a7fdbe
- Script: `VOL_E2E_NETWORK=base-sepolia DIRECT_SIMULATE=1 ./script/demo-with-txids.sh`

This direct simulation proves destination-side authorization and fee update behavior against the real Base Sepolia demo PoolId.

## Blockers

- `observedSwaps()` via normal `eth_call` still returns `0`, but this is not the authoritative ReactVM state proof. Use `rnk_getVm` and `rnk_getTransactions` for RVM execution evidence.
- Origin events are proven on Base Sepolia and RNK RVM executions are proven on Lasna for six origin `SwapPriceUpdate` transactions.
- `rnk_getTransactionByHash(rvmId, txHash)` returns `rData == 0x` for the six observed RVM executions, so the legacy RPC is not exposing decoded RSC-emitted callback logs there.
- A live destination callback transaction through `callbackProxy -> updateFeeFromReactive(address,bytes32,uint24)` has not been observed yet. The visible Base Sepolia `FeeUpdated` tx is the direct reactive-sender simulation, not the proxy callback path.
- `callbackDebt()` currently reverts against the configured legacy system contract on Base Sepolia, so callback payment/debt status needs Reactive team confirmation for this legacy endpoint/proxy.

## Reactive Debug Attempts - 2026-06-10

Base Sepolia high-vol retry:

- Reconfigured original Base RSC subscription: https://lasna.reactscan.net/tx/0xca4dda6d1dd98c8903b9f7485ab23883f6cf1b55b9a5f5e0c9db14bc8f97037f
- Fresh high-notional Base `SwapPriceUpdate` txs:
  - https://sepolia.basescan.org/tx/0xf47ddc7bfde9a7d5fbb0e72cb73d1688a32d0dd16cd6f3d8d5064d4682d3c2ed
  - https://sepolia.basescan.org/tx/0xc230f04519dd805cff9e0c81fcd6c20bf35e3532a910a5c5a7444ebd9c70b136
  - https://sepolia.basescan.org/tx/0xf1f636de6dbd1b30cc172fe96d72e024e54e7a6fdcf50ef02d9caefec04cc3f2
- Result: RNK tail stayed pinned at `lastTxNumber == 0x656`.

Unichain Sepolia retry:

- Hook: `0x7374f2cf24db9Ec6B1FD6B2e42803e25451590C0`
- Hook deploy tx: https://sepolia.uniscan.xyz/tx/0x00b129171f577442408000f91889f43c0b22075303dffe3b64627915313988c5
- PoolId: `0xb169e2e03c3fc5ac742bd5bb7a402cb2fe0705af0e50aed5ec2fb8c1c8b940f8`
- Token0: `0x13569B3eA76617c4A0AF4bfB446Cef8fAaa710b3`
- Token1: `0x35faFde6313D112B6C1F4CC7AFe480110736E8bD`
- RSC: `0x0b6A0eB9ACC4a0369Dc774b854a3dBC543CcF1e8`
- RSC deploy tx: https://lasna.reactscan.net/tx/0xa30bd1a3eeb647ea17717094414e85c5e2327244736c75e9b74233465561c1ad
- RSC subscription tx: https://lasna.reactscan.net/tx/0xfac8a39e6d54ee930bef251e03e2662da99af8497b7ad49665ba0146b1e8c0b8
- Fresh Unichain `SwapPriceUpdate` txs:
  - https://sepolia.uniscan.xyz/tx/0x092827380c825aa3e7be02177c2805802fabeeb347e50a57cb490729700b5b1b
  - https://sepolia.uniscan.xyz/tx/0x1d84c70eac7ce0c187f941f559004281c233d955f51198b271cf7d3ff1087a98
  - https://sepolia.uniscan.xyz/tx/0x5a661b8f4d539aad8f7bdcc281fc50b0adb6d87d36ca7a2a722301e3aef73837
- Result: RNK tail for the saturated sender stayed pinned at `lastTxNumber == 0x656`.

Fresh RVM sender retry:

- Fresh RVM sender: `0x36c981905c78392F7cFF6b832a40B17C7f3626a5`
- Lasna funding tx: https://lasna.reactscan.net/tx/0x4b71c913cd00f664cd33c3e1c98ee0cf357c944703d7efe09faab4a3d826d937
- Fresh-sender hook: `0xF170Df36c6b45EDcCD685B9916ef126148F0D0c0`
- Fresh-sender hook deploy tx: https://sepolia.uniscan.xyz/tx/0x70642e67d16a878a283e4c483882786f4ab7557ff8f3857a0f4bb79a37ac2e91
- Fresh-sender PoolId: `0x689f1a898cdd9526fd6bf893e77ef69e1511335b95b6f45820bd66a899a93bae`
- Fresh-sender token0: `0x07Ccde2c816DEF55421f20298E9E897C8b600902`
- Fresh-sender token1: `0x6fA9ef5BA0eA2983567721186e76878443D847A7`
- Lightweight callback RSC: `0x83c1416708a36cc2C52dE9Af280B98ebf42C9A61`
- Lightweight callback RSC deploy tx: https://lasna.reactscan.net/tx/0x9638361e0d295cdee6aba7817390971b680b3d45e2631f4535ee0a6249205fcd
- Lightweight callback RSC subscription tx: https://lasna.reactscan.net/tx/0xe878e6c11f55b4f072fb6ae685ee77eb4f6ad87fc9f3f2689d31c664d18270f0
- Fresh-sender Unichain `SwapPriceUpdate` txs:
  - https://sepolia.uniscan.xyz/tx/0x3dd0cf1f8ea3a10cf3b448dde0aeb0ce23d8d08cd612561e5330568c1d7c457f
  - https://sepolia.uniscan.xyz/tx/0x01df3e4db01b08f9f25dda54d0a641f75725185401879d3c86d0c0b88b52cc6d
  - https://sepolia.uniscan.xyz/tx/0xdf6c9831dfaa4cfdd6a6fd0a48345b96007d85f14d8f9693eaa8960226eb6323
- Result: `rnk_getVm(0x36c981905c78392F7cFF6b832a40B17C7f3626a5)` returned `RVM not found` through the polling window, and `rnk_getFilters` did not yet show the fresh subscription despite the successful system `Subscribe` receipt.
