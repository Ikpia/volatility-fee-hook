// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {BeforeSwapDelta} from "@uniswap/v4-core/src/types/BeforeSwapDelta.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId} from "@uniswap/v4-core/src/types/PoolId.sol";
import {SwapParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {BaseHook} from "v4-hooks-public/src/base/BaseHook.sol";
import {VolatilityFeeHook} from "../../src/VolatilityFeeHook.sol";

contract VolatilityFeeHookHarness is VolatilityFeeHook {
    uint160 internal sqrtPriceX96;

    constructor(
        IPoolManager manager,
        address callbackProxy,
        address reactiveSender,
        uint24 feeTierLow,
        uint24 feeTierMedium,
        uint24 feeTierHigh,
        uint256 volThresholdLow,
        uint256 volThresholdHigh
    )
        VolatilityFeeHook(
            manager,
            callbackProxy,
            reactiveSender,
            feeTierLow,
            feeTierMedium,
            feeTierHigh,
            volThresholdLow,
            volThresholdHigh
        )
    {}

    function setSqrtPrice(uint160 newSqrtPriceX96) external {
        sqrtPriceX96 = newSqrtPriceX96;
    }

    function exposedAfterInitialize(address sender, PoolKey calldata key, uint160 initialSqrtPriceX96, int24 tick)
        external
        returns (bytes4)
    {
        return _afterInitialize(sender, key, initialSqrtPriceX96, tick);
    }

    function exposedBeforeSwap(address sender, PoolKey calldata key, SwapParams calldata params, bytes calldata hookData)
        external
        view
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        return _beforeSwap(sender, key, params, hookData);
    }

    function exposedAfterSwap(
        address sender,
        PoolKey calldata key,
        SwapParams calldata params,
        BalanceDelta delta,
        bytes calldata hookData
    ) external returns (bytes4, int128) {
        return _afterSwap(sender, key, params, delta, hookData);
    }

    function _readSqrtPrice(PoolId) internal view override returns (uint160) {
        return sqrtPriceX96;
    }

    function validateHookAddress(BaseHook) internal pure override {}
}

contract StateReadVolatilityFeeHookHarness is VolatilityFeeHook {
    constructor(
        IPoolManager manager,
        address callbackProxy,
        address reactiveSender,
        uint24 feeTierLow,
        uint24 feeTierMedium,
        uint24 feeTierHigh,
        uint256 volThresholdLow,
        uint256 volThresholdHigh
    )
        VolatilityFeeHook(
            manager,
            callbackProxy,
            reactiveSender,
            feeTierLow,
            feeTierMedium,
            feeTierHigh,
            volThresholdLow,
            volThresholdHigh
        )
    {}

    function exposedAfterInitialize(address sender, PoolKey calldata key, uint160 initialSqrtPriceX96, int24 tick)
        external
        returns (bytes4)
    {
        return _afterInitialize(sender, key, initialSqrtPriceX96, tick);
    }

    function exposedAfterSwap(
        address sender,
        PoolKey calldata key,
        SwapParams calldata params,
        BalanceDelta delta,
        bytes calldata hookData
    ) external returns (bytes4, int128) {
        return _afterSwap(sender, key, params, delta, hookData);
    }

    function validateHookAddress(BaseHook) internal pure override {}
}
