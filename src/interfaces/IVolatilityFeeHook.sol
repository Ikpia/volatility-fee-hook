// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {PoolId} from "@uniswap/v4-core/src/types/PoolId.sol";

interface IVolatilityFeeHook {
    struct VolatilityState {
        uint24 currentFee;
        uint160 lastSqrtPrice;
        uint256 lastUpdateBlock;
        uint256 swapCount;
    }

    event SwapPriceUpdate(PoolId indexed poolId, uint160 sqrtPriceX96, uint256 blockTimestamp);
    event FeeUpdated(PoolId indexed poolId, uint24 oldFee, uint24 newFee, uint256 blockNumber);

    function updateFee(PoolId poolId, uint24 newFee) external;
    function updateFeeFromReactive(address sender, bytes32 poolId, uint24 newFee) external;
    function getVolatilityState(PoolId poolId) external view returns (VolatilityState memory);
}
