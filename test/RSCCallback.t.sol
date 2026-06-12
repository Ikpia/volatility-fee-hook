// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Test} from "forge-std/Test.sol";
import {IReactive} from "reactive-lib/interfaces/IReactive.sol";
import {VolatilityFeeRSC} from "../src/rsc/VolatilityFeeRSC.sol";

contract RSCCallbackTest is Test {
    address internal constant REACTIVE_SYSTEM = 0x0000000000000000000000000000000000fffFfF;

    VolatilityFeeRSC rsc;
    bytes32 poolId = keccak256("POOL");
    address hook = address(0xBEEF);

    event Callback(uint256 indexed chain_id, address indexed _contract, uint64 indexed gas_limit, bytes payload);

    function setUp() public {
        rsc = new VolatilityFeeRSC(84532, hook, 50_000, 1e15, 5e15, 3);
    }

    function testConstructorAndSubscriptionGuards() public {
        vm.expectRevert(VolatilityFeeRSC.InvalidConfig.selector);
        new VolatilityFeeRSC(84532, address(0), 50_000, 1e15, 5e15, 3);

        vm.expectRevert(VolatilityFeeRSC.InvalidConfig.selector);
        new VolatilityFeeRSC(84532, hook, 50_000, 5e15, 1e15, 3);

        VolatilityFeeRSC defaultMin = new VolatilityFeeRSC(84532, hook, 50_000, 1e15, 5e15, 0);
        assertEq(defaultMin.MIN_SWAPS_BEFORE_UPDATE(), 3);

        vm.prank(address(0xBAD));
        vm.expectRevert(VolatilityFeeRSC.OnlySubscriptionAdmin.selector);
        rsc.configureSubscription();

        vm.expectEmit(false, false, false, true, address(rsc));
        emit VolatilityFeeRSC.SubscriptionUnavailable();
        rsc.configureSubscription();
    }

    function testSubscriptionSuccessOnReactiveNetworkCopy() public {
        vm.etch(REACTIVE_SYSTEM, address(new MockReactiveSystemOk()).code);
        VolatilityFeeRSC rnCopy = new VolatilityFeeRSC(84532, hook, 50_000, 1e15, 5e15, 3);
        assertTrue(rnCopy.subscriptionConfigured());
    }

    function testSubscriptionFailureCanRevertWhenConfiguredDirectly() public {
        vm.etch(REACTIVE_SYSTEM, address(new MockReactiveSystemRevert()).code);
        VolatilityFeeRSC rnCopy = new VolatilityFeeRSC(84532, hook, 50_000, 1e15, 5e15, 3);
        assertFalse(rnCopy.subscriptionConfigured());
        vm.expectRevert(VolatilityFeeRSC.SubscriptionFailed.selector);
        rnCopy.configureSubscription();
    }

    function testCallbackThrottling() public {
        _react(1e18);
        _react(11e17);
        assertEq(rsc.swapsSinceUpdate(poolId), 2);

        bytes memory payload =
            abi.encodeWithSignature("updateFeeFromReactive(address,bytes32,uint24)", address(this), poolId, uint24(10_000));
        vm.expectEmit(true, true, true, true, address(rsc));
        emit Callback(84532, hook, 50_000, payload);
        _react(12e17);
        assertEq(rsc.lastPushedFee(poolId), 10_000);
        assertEq(rsc.swapsSinceUpdate(poolId), 0);
    }

    function testNoCallbackWhenTierUnchanged() public {
        _react(1e18);
        _react(1e18);
        _react(1e18);
        assertEq(rsc.lastPushedFee(poolId), 0);
    }

    function testEndToEndVolSpikeThenLowerFeeCallback() public {
        _react(1e18);
        _react(2e18);
        _react(3e18);
        assertEq(rsc.lastPushedFee(poolId), 10_000);

        for (uint256 i; i < 90; i++) {
            _react(3e18);
        }
        assertEq(rsc.lastPushedFee(poolId), 500);
    }

    function _react(uint160 sqrtPriceX96) internal {
        IReactive.LogRecord memory log = IReactive.LogRecord({
            chain_id: 84532,
            _contract: hook,
            topic_0: rsc.SWAP_PRICE_UPDATE_TOPIC(),
            topic_1: uint256(poolId),
            topic_2: 0,
            topic_3: 0,
            data: abi.encode(sqrtPriceX96, block.timestamp),
            block_number: block.number,
            op_code: 0,
            block_hash: 0,
            tx_hash: 0,
            log_index: 0
        });
        rsc.react(log);
    }
}

contract MockReactiveSystemOk {
    receive() external payable {}

    function debt(address) external pure returns (uint256) {
        return 0;
    }

    function subscribe(uint256, address, uint256, uint256, uint256, uint256) external pure {}

    function unsubscribe(uint256, address, uint256, uint256, uint256, uint256) external pure {}
}

contract MockReactiveSystemRevert {
    receive() external payable {}

    function debt(address) external pure returns (uint256) {
        return 0;
    }

    function subscribe(uint256, address, uint256, uint256, uint256, uint256) external pure {
        revert("SUBSCRIBE_FAILED");
    }

    function unsubscribe(uint256, address, uint256, uint256, uint256, uint256) external pure {}
}
