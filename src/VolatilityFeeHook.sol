// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {BaseHook} from "v4-hooks-public/src/base/BaseHook.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {LPFeeLibrary} from "@uniswap/v4-core/src/libraries/LPFeeLibrary.sol";
import {StateLibrary} from "@uniswap/v4-core/src/libraries/StateLibrary.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "@uniswap/v4-core/src/types/BeforeSwapDelta.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {SwapParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {IVolatilityFeeHook} from "./interfaces/IVolatilityFeeHook.sol";

interface IReactivePayable {
    function debt(address contract_) external view returns (uint256 debt_);
}

contract VolatilityFeeHook is BaseHook, IVolatilityFeeHook {
    using PoolIdLibrary for PoolKey;
    using StateLibrary for IPoolManager;

    error InvalidAddress();
    error InvalidFeeTier();
    error NotReactiveSender();
    error NotCallbackProxy();

    mapping(PoolId => VolatilityState) internal _volatilityState;

    address public immutable callbackProxy;
    address public immutable reactiveSender;
    uint24 public immutable feeTierLow;
    uint24 public immutable feeTierMedium;
    uint24 public immutable feeTierHigh;
    uint256 public immutable volThresholdLow;
    uint256 public immutable volThresholdHigh;

    constructor(
        IPoolManager _poolManager,
        address _callbackProxy,
        address _reactiveSender,
        uint24 _feeTierLow,
        uint24 _feeTierMedium,
        uint24 _feeTierHigh,
        uint256 _volThresholdLow,
        uint256 _volThresholdHigh
    ) BaseHook(_poolManager) {
        if (_callbackProxy == address(0) || _reactiveSender == address(0)) revert InvalidAddress();
        _validateFeeTier(_feeTierLow);
        _validateFeeTier(_feeTierMedium);
        _validateFeeTier(_feeTierHigh);
        if (!(_feeTierLow < _feeTierMedium && _feeTierMedium < _feeTierHigh)) revert InvalidFeeTier();
        if (!(_volThresholdLow < _volThresholdHigh)) revert InvalidFeeTier();

        callbackProxy = _callbackProxy;
        reactiveSender = _reactiveSender;
        feeTierLow = _feeTierLow;
        feeTierMedium = _feeTierMedium;
        feeTierHigh = _feeTierHigh;
        volThresholdLow = _volThresholdLow;
        volThresholdHigh = _volThresholdHigh;
    }

    receive() external payable {}

    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: true,
            beforeAddLiquidity: false,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: false,
            afterRemoveLiquidity: false,
            beforeSwap: true,
            afterSwap: true,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    function getVolatilityState(PoolId poolId) external view returns (VolatilityState memory) {
        return _volatilityState[poolId];
    }

    function callbackDebt() external view returns (uint256) {
        return IReactivePayable(callbackProxy).debt(address(this));
    }

    function coverCallbackDebt() external {
        uint256 debt = IReactivePayable(callbackProxy).debt(address(this));
        if (debt != 0) _pay(payable(callbackProxy), debt);
    }

    function pay(uint256 amount) external {
        if (msg.sender != callbackProxy) revert NotCallbackProxy();
        _pay(payable(msg.sender), amount);
    }

    function updateFee(PoolId poolId, uint24 newFee) external {
        if (msg.sender != reactiveSender) revert NotReactiveSender();
        _updateFee(poolId, newFee);
    }

    function updateFeeFromReactive(address sender, bytes32 poolId, uint24 newFee) external {
        if (msg.sender != callbackProxy) revert NotCallbackProxy();
        if (sender != reactiveSender) revert NotReactiveSender();
        _updateFee(PoolId.wrap(poolId), newFee);
    }

    function _afterInitialize(address, PoolKey calldata key, uint160 sqrtPriceX96, int24)
        internal
        override
        returns (bytes4)
    {
        PoolId poolId = key.toId();
        _volatilityState[poolId] = VolatilityState({
            currentFee: feeTierLow,
            lastSqrtPrice: sqrtPriceX96,
            lastUpdateBlock: block.number,
            swapCount: 0
        });
        return IHooks.afterInitialize.selector;
    }

    function _beforeSwap(address, PoolKey calldata key, SwapParams calldata, bytes calldata)
        internal
        view
        override
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        uint24 fee = _volatilityState[key.toId()].currentFee;
        if (fee == 0) fee = feeTierLow;
        return (IHooks.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, fee | LPFeeLibrary.OVERRIDE_FEE_FLAG);
    }

    function _afterSwap(address, PoolKey calldata key, SwapParams calldata, BalanceDelta, bytes calldata)
        internal
        override
        returns (bytes4, int128)
    {
        PoolId poolId = key.toId();
        uint160 sqrtPriceX96 = _readSqrtPrice(poolId);
        VolatilityState storage state = _volatilityState[poolId];
        state.lastSqrtPrice = sqrtPriceX96;
        state.swapCount++;
        emit SwapPriceUpdate(poolId, sqrtPriceX96, block.timestamp);
        return (IHooks.afterSwap.selector, 0);
    }

    function _readSqrtPrice(PoolId poolId) internal view virtual returns (uint160 sqrtPriceX96) {
        (sqrtPriceX96,,,) = poolManager.getSlot0(poolId);
    }

    function _updateFee(PoolId poolId, uint24 newFee) internal {
        if (newFee != feeTierLow && newFee != feeTierMedium && newFee != feeTierHigh) revert InvalidFeeTier();
        VolatilityState storage state = _volatilityState[poolId];
        uint24 oldFee = state.currentFee;
        if (oldFee == 0) oldFee = feeTierLow;
        state.currentFee = newFee;
        state.lastUpdateBlock = block.number;
        emit FeeUpdated(poolId, oldFee, newFee, block.number);
    }

    function _validateFeeTier(uint24 fee) internal pure {
        if (!LPFeeLibrary.isValid(fee)) revert InvalidFeeTier();
    }

    function _pay(address payable to, uint256 amount) internal {
        if (amount == 0) return;
        (bool ok,) = to.call{value: amount}("");
        require(ok, "PAY_FAILED");
    }
}
