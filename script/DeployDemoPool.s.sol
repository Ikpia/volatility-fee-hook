// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Script, console2} from "forge-std/Script.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {LPFeeLibrary} from "@uniswap/v4-core/src/libraries/LPFeeLibrary.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {ModifyLiquidityParams, SwapParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {PoolModifyLiquidityTest} from "@uniswap/v4-core/src/test/PoolModifyLiquidityTest.sol";
import {PoolSwapTest} from "@uniswap/v4-core/src/test/PoolSwapTest.sol";
import {DemoERC20} from "../src/demo/DemoERC20.sol";

contract DeployVolatilityFeeDemoPool is Script {
    using PoolIdLibrary for PoolKey;

    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);
        IPoolManager poolManager = IPoolManager(vm.envAddress("POOL_MANAGER"));
        address hook = vm.envAddress("VOLATILITY_FEE_HOOK");
        address modifyLiquidityRouter = vm.envAddress("POOL_MODIFY_LIQUIDITY_TEST");
        address swapRouter = vm.envAddress("POOL_SWAP_TEST");
        uint256 initialSupply = vm.envOr("DEMO_TOKEN_SUPPLY", uint256(10_000_000 ether));
        uint128 liquidity = uint128(vm.envOr("DEMO_LIQUIDITY", uint256(100 ether)));
        int24 tickSpacing = int24(int256(vm.envOr("DEMO_TICK_SPACING", int256(60))));
        int24 tickLower = int24(int256(vm.envOr("DEMO_TICK_LOWER", int256(-600))));
        int24 tickUpper = int24(int256(vm.envOr("DEMO_TICK_UPPER", int256(600))));
        int256 swapAmount = -int256(vm.envOr("DEMO_SWAP_AMOUNT", uint256(0.01 ether)));

        vm.startBroadcast(deployerKey);

        DemoERC20 tokenA = new DemoERC20("Volatility Demo Token A", "vDTA", initialSupply);
        DemoERC20 tokenB = new DemoERC20("Volatility Demo Token B", "vDTB", initialSupply);

        (DemoERC20 token0, DemoERC20 token1) =
            address(tokenA) < address(tokenB) ? (tokenA, tokenB) : (tokenB, tokenA);

        token0.approve(modifyLiquidityRouter, type(uint256).max);
        token1.approve(modifyLiquidityRouter, type(uint256).max);
        token0.approve(swapRouter, type(uint256).max);
        token1.approve(swapRouter, type(uint256).max);

        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(address(token0)),
            currency1: Currency.wrap(address(token1)),
            fee: LPFeeLibrary.DYNAMIC_FEE_FLAG,
            tickSpacing: tickSpacing,
            hooks: IHooks(hook)
        });

        poolManager.initialize(key, TickMath.getSqrtPriceAtTick(0));

        PoolModifyLiquidityTest(modifyLiquidityRouter).modifyLiquidity(
            key,
            ModifyLiquidityParams({
                tickLower: tickLower,
                tickUpper: tickUpper,
                liquidityDelta: int256(uint256(liquidity)),
                // forge-lint: disable-next-line(unsafe-typecast)
                salt: bytes32("VOL_FEE_DEMO")
            }),
            ""
        );

        PoolSwapTest.TestSettings memory settings =
            PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false});
        PoolSwapTest(swapRouter).swap(
            key,
            SwapParams({
                zeroForOne: true,
                amountSpecified: swapAmount,
                sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
            }),
            settings,
            ""
        );
        PoolSwapTest(swapRouter).swap(
            key,
            SwapParams({
                zeroForOne: false,
                amountSpecified: swapAmount,
                sqrtPriceLimitX96: TickMath.MAX_SQRT_PRICE - 1
            }),
            settings,
            ""
        );

        vm.stopBroadcast();

        PoolId poolId = key.toId();
        console2.log("Deployer", deployer);
        console2.log("PoolManager", address(poolManager));
        console2.log("VolatilityFeeHook", hook);
        console2.log("token0", address(token0));
        console2.log("token1", address(token1));
        console2.log("PoolModifyLiquidityTest", modifyLiquidityRouter);
        console2.log("PoolSwapTest", swapRouter);
        console2.log("tickLower", int256(tickLower));
        console2.log("tickUpper", int256(tickUpper));
        console2.log("liquidity", liquidity);
        console2.logBytes32(PoolId.unwrap(poolId));
    }
}
