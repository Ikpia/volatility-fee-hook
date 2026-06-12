// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Test} from "forge-std/Test.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {LPFeeLibrary} from "@uniswap/v4-core/src/libraries/LPFeeLibrary.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {BeforeSwapDelta} from "@uniswap/v4-core/src/types/BeforeSwapDelta.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {SwapParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {VolatilityFeeHook} from "../src/VolatilityFeeHook.sol";
import {VolatilityFeeHookHarness} from "./utils/VolatilityFeeHookHarness.sol";
import {StateReadVolatilityFeeHookHarness} from "./utils/VolatilityFeeHookHarness.sol";

contract VolatilityFeeHookTest is Test {
    using PoolIdLibrary for PoolKey;

    VolatilityFeeHookHarness hook;
    PoolKey key;
    PoolId poolId;

    address callbackProxy = address(0xCA11BAC);
    address reactiveSender = address(0xA11CE);
    uint160 initialPrice = 1_000_000_000_000_000_000;

    event SwapPriceUpdate(PoolId indexed poolId, uint160 sqrtPriceX96, uint256 blockTimestamp);
    event FeeUpdated(PoolId indexed poolId, uint24 oldFee, uint24 newFee, uint256 blockNumber);

    function setUp() public {
        hook = new VolatilityFeeHookHarness(
            IPoolManager(address(0xBEEF)),
            callbackProxy,
            reactiveSender,
            500,
            3000,
            10_000,
            1e15,
            5e15
        );
        key = PoolKey({
            currency0: Currency.wrap(address(0x1000)),
            currency1: Currency.wrap(address(0x2000)),
            fee: LPFeeLibrary.DYNAMIC_FEE_FLAG,
            tickSpacing: 60,
            hooks: IHooks(address(hook))
        });
        poolId = key.toId();
    }

    function testHookPermissionsAreMinimalForDynamicFee() public view {
        Hooks.Permissions memory p = hook.getHookPermissions();
        assertTrue(p.afterInitialize);
        assertTrue(p.beforeSwap);
        assertTrue(p.afterSwap);
        assertFalse(p.beforeSwapReturnDelta);
        assertFalse(p.afterSwapReturnDelta);
        assertFalse(p.beforeAddLiquidity);
        assertFalse(p.beforeRemoveLiquidity);
    }

    function testInitialFeeIsLow() public {
        hook.exposedAfterInitialize(address(this), key, initialPrice, 0);
        assertEq(hook.getVolatilityState(poolId).currentFee, 500);
        assertEq(hook.getVolatilityState(poolId).lastSqrtPrice, initialPrice);
    }

    function testBeforeSwapReturnsDynamicFeeOverride() public {
        hook.exposedAfterInitialize(address(this), key, initialPrice, 0);
        (, BeforeSwapDelta delta, uint24 fee) =
            hook.exposedBeforeSwap(address(this), key, _swapParams(), "");
        assertEq(BeforeSwapDelta.unwrap(delta), 0);
        assertEq(fee, 500 | LPFeeLibrary.OVERRIDE_FEE_FLAG);
    }

    function testBeforeSwapDefaultsToLowBeforeInitialize() public view {
        (,, uint24 fee) = hook.exposedBeforeSwap(address(this), key, _swapParams(), "");
        assertEq(fee, 500 | LPFeeLibrary.OVERRIDE_FEE_FLAG);
    }

    function testAfterSwapEmitsEventAndIncrementsCount() public {
        hook.exposedAfterInitialize(address(this), key, initialPrice, 0);
        hook.setSqrtPrice(initialPrice + 100);
        vm.expectEmit(true, false, false, true, address(hook));
        emit SwapPriceUpdate(poolId, initialPrice + 100, block.timestamp);
        hook.exposedAfterSwap(address(this), key, _swapParams(), BalanceDelta.wrap(0), "");
        assertEq(hook.getVolatilityState(poolId).lastSqrtPrice, initialPrice + 100);
        assertEq(hook.getVolatilityState(poolId).swapCount, 1);
    }

    function testAfterSwapReadsSqrtPriceFromPoolManagerSlot0() public {
        MockPoolManagerExtsload manager = new MockPoolManagerExtsload();
        StateReadVolatilityFeeHookHarness stateHook = new StateReadVolatilityFeeHookHarness(
            IPoolManager(address(manager)), callbackProxy, reactiveSender, 500, 3000, 10_000, 1e15, 5e15
        );
        PoolKey memory stateKey = PoolKey({
            currency0: Currency.wrap(address(0x1000)),
            currency1: Currency.wrap(address(0x2000)),
            fee: LPFeeLibrary.DYNAMIC_FEE_FLAG,
            tickSpacing: 60,
            hooks: IHooks(address(stateHook))
        });
        PoolId statePoolId = stateKey.toId();
        manager.setSlot0(initialPrice + 777);
        stateHook.exposedAfterInitialize(address(this), stateKey, initialPrice, 0);
        stateHook.exposedAfterSwap(address(this), stateKey, _swapParams(), BalanceDelta.wrap(0), "");
        assertEq(stateHook.getVolatilityState(statePoolId).lastSqrtPrice, initialPrice + 777);
    }

    function testUpdateFeeOnlyReactiveSender() public {
        hook.exposedAfterInitialize(address(this), key, initialPrice, 0);
        vm.expectRevert(VolatilityFeeHook.NotReactiveSender.selector);
        hook.updateFee(poolId, 3000);

        vm.prank(reactiveSender);
        vm.expectEmit(true, false, false, true, address(hook));
        emit FeeUpdated(poolId, 500, 3000, block.number);
        hook.updateFee(poolId, 3000);
        assertEq(hook.getVolatilityState(poolId).currentFee, 3000);
    }

    function testReactiveCallbackRequiresProxyAndSenderIdentity() public {
        hook.exposedAfterInitialize(address(this), key, initialPrice, 0);

        vm.expectRevert(VolatilityFeeHook.NotCallbackProxy.selector);
        hook.updateFeeFromReactive(reactiveSender, PoolId.unwrap(poolId), 3000);

        vm.prank(callbackProxy);
        vm.expectRevert(VolatilityFeeHook.NotReactiveSender.selector);
        hook.updateFeeFromReactive(address(0xBAD), PoolId.unwrap(poolId), 3000);

        vm.prank(callbackProxy);
        hook.updateFeeFromReactive(reactiveSender, PoolId.unwrap(poolId), 10_000);
        assertEq(hook.getVolatilityState(poolId).currentFee, 10_000);
    }

    function testUpdateFeeRejectsInvalidTier() public {
        hook.exposedAfterInitialize(address(this), key, initialPrice, 0);
        vm.prank(reactiveSender);
        vm.expectRevert(VolatilityFeeHook.InvalidFeeTier.selector);
        hook.updateFee(poolId, 999);
    }

    function testUpdateFeeBeforeInitializeEmitsLowAsOldFee() public {
        vm.prank(reactiveSender);
        vm.expectEmit(true, false, false, true, address(hook));
        emit FeeUpdated(poolId, 500, 3000, block.number);
        hook.updateFee(poolId, 3000);
        assertEq(hook.getVolatilityState(poolId).currentFee, 3000);
    }

    function testCallbackDebtAndPaymentHelpers() public {
        MockCallbackProxy proxy = new MockCallbackProxy();
        VolatilityFeeHookHarness paymentHook = new VolatilityFeeHookHarness(
            IPoolManager(address(0xBEEF)), address(proxy), reactiveSender, 500, 3000, 10_000, 1e15, 5e15
        );
        vm.deal(address(paymentHook), 1 ether);
        proxy.setDebt(address(paymentHook), 0.2 ether);

        assertEq(paymentHook.callbackDebt(), 0.2 ether);
        paymentHook.coverCallbackDebt();
        assertEq(address(proxy).balance, 0.2 ether);

        vm.prank(address(proxy));
        paymentHook.pay(0);
        vm.prank(address(proxy));
        paymentHook.pay(0.1 ether);
        assertEq(address(proxy).balance, 0.3 ether);

        vm.expectRevert(VolatilityFeeHook.NotCallbackProxy.selector);
        paymentHook.pay(1);
    }

    function testPaymentFailureReverts() public {
        RejectingCallbackProxy proxy = new RejectingCallbackProxy();
        VolatilityFeeHookHarness paymentHook = new VolatilityFeeHookHarness(
            IPoolManager(address(0xBEEF)), address(proxy), reactiveSender, 500, 3000, 10_000, 1e15, 5e15
        );
        vm.deal(address(paymentHook), 1 ether);
        proxy.setDebt(address(paymentHook), 0.1 ether);

        vm.expectRevert(bytes("PAY_FAILED"));
        paymentHook.coverCallbackDebt();
    }

    function testFeeReadAfterUpdate() public {
        hook.exposedAfterInitialize(address(this), key, initialPrice, 0);
        vm.prank(reactiveSender);
        hook.updateFee(poolId, 3000);
        (,, uint24 fee) = hook.exposedBeforeSwap(address(this), key, _swapParams(), "");
        assertEq(fee, 3000 | LPFeeLibrary.OVERRIDE_FEE_FLAG);
    }

    function testConstructorGuardsConfig() public {
        vm.expectRevert(VolatilityFeeHook.InvalidAddress.selector);
        new VolatilityFeeHookHarness(IPoolManager(address(1)), address(0), reactiveSender, 500, 3000, 10_000, 1e15, 5e15);

        vm.expectRevert(VolatilityFeeHook.InvalidAddress.selector);
        new VolatilityFeeHookHarness(IPoolManager(address(1)), callbackProxy, address(0), 500, 3000, 10_000, 1e15, 5e15);

        vm.expectRevert(VolatilityFeeHook.InvalidFeeTier.selector);
        new VolatilityFeeHookHarness(
            IPoolManager(address(1)), callbackProxy, reactiveSender, 500, 3000, 1_000_001, 1e15, 5e15
        );

        vm.expectRevert(VolatilityFeeHook.InvalidFeeTier.selector);
        new VolatilityFeeHookHarness(IPoolManager(address(1)), callbackProxy, reactiveSender, 3000, 500, 10_000, 1e15, 5e15);

        vm.expectRevert(VolatilityFeeHook.InvalidFeeTier.selector);
        new VolatilityFeeHookHarness(IPoolManager(address(1)), callbackProxy, reactiveSender, 500, 3000, 10_000, 5e15, 1e15);
    }

    function testReceiveAcceptsNativeToken() public {
        vm.deal(address(this), 1 ether);
        (bool ok,) = address(hook).call{value: 0.25 ether}("");
        assertTrue(ok);
        assertEq(address(hook).balance, 0.25 ether);
    }

    function _swapParams() internal pure returns (SwapParams memory) {
        return SwapParams({zeroForOne: true, amountSpecified: -1e18, sqrtPriceLimitX96: 1});
    }
}

contract MockCallbackProxy {
    mapping(address => uint256) public debt;

    receive() external payable {}

    function setDebt(address account, uint256 amount) external {
        debt[account] = amount;
    }
}

contract RejectingCallbackProxy {
    mapping(address => uint256) public debt;

    receive() external payable {
        revert("NO_RECEIVE");
    }

    function setDebt(address account, uint256 amount) external {
        debt[account] = amount;
    }
}

contract MockPoolManagerExtsload {
    bytes32 internal slot0;

    function setSlot0(uint160 sqrtPriceX96) external {
        slot0 = bytes32(uint256(sqrtPriceX96));
    }

    function extsload(bytes32) external view returns (bytes32) {
        return slot0;
    }
}
