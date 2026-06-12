// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Script, console2} from "forge-std/Script.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {LPFeeLibrary} from "@uniswap/v4-core/src/libraries/LPFeeLibrary.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {SwapParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {PoolSwapTest} from "@uniswap/v4-core/src/test/PoolSwapTest.sol";

contract RunVolatilityFeeDemoSwaps is Script {
    using PoolIdLibrary for PoolKey;

    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);
        address hook = vm.envAddress("VOLATILITY_FEE_HOOK");
        address swapRouter = vm.envAddress("POOL_SWAP_TEST");
        address token0 = vm.envAddress("DEMO_TOKEN0");
        address token1 = vm.envAddress("DEMO_TOKEN1");
        int24 tickSpacing = int24(int256(vm.envOr("DEMO_TICK_SPACING", int256(60))));
        uint256 rounds = vm.envOr("DEMO_SWAP_ROUNDS", uint256(3));
        int256 swapAmount = -int256(vm.envOr("DEMO_SWAP_AMOUNT", uint256(0.01 ether)));

        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: LPFeeLibrary.DYNAMIC_FEE_FLAG,
            tickSpacing: tickSpacing,
            hooks: IHooks(hook)
        });

        PoolSwapTest.TestSettings memory settings =
            PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false});

        vm.startBroadcast(deployerKey);
        IERC20(token0).approve(swapRouter, type(uint256).max);
        IERC20(token1).approve(swapRouter, type(uint256).max);

        for (uint256 i; i < rounds; i++) {
            bool zeroForOne = i % 2 == 0;
            PoolSwapTest(swapRouter).swap(
                key,
                SwapParams({
                    zeroForOne: zeroForOne,
                    amountSpecified: swapAmount,
                    sqrtPriceLimitX96: zeroForOne ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1
                }),
                settings,
                ""
            );
        }
        vm.stopBroadcast();

        PoolId poolId = key.toId();
        console2.log("Deployer", deployer);
        console2.log("VolatilityFeeHook", hook);
        console2.log("PoolSwapTest", swapRouter);
        console2.log("token0", token0);
        console2.log("token1", token1);
        console2.log("rounds", rounds);
        console2.log("swapAmount", swapAmount);
        console2.logBytes32(PoolId.unwrap(poolId));
    }
}
