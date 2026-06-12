// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Test} from "forge-std/Test.sol";
import {IReactive} from "reactive-lib/interfaces/IReactive.sol";
import {VolatilityFeeCallbackRSC} from "../src/rsc/VolatilityFeeCallbackRSC.sol";

contract CallbackRSCTest is Test {
    address internal constant REACTIVE_SYSTEM = 0x0000000000000000000000000000000000fffFfF;

    VolatilityFeeCallbackRSC rsc;

    bytes32 poolId = keccak256("POOL");
    address hook = address(0xBEEF);

    event Callback(uint256 indexed chain_id, address indexed _contract, uint64 indexed gas_limit, bytes payload);

    function setUp() public {
        vm.etch(REACTIVE_SYSTEM, address(new MockReactiveSystemOk()).code);
        rsc = new VolatilityFeeCallbackRSC(1301, hook, 120_000, 3000);
    }

    function testQueuesConfiguredCallbackForAnySwapPriceUpdate() public {
        bytes memory payload =
            abi.encodeWithSignature("updateFeeFromReactive(address,bytes32,uint24)", address(this), poolId, uint24(3000));

        vm.expectEmit(true, true, true, true, address(rsc));
        emit Callback(1301, hook, 120_000, payload);

        rsc.react(_log());
    }

    function testConfigureSubscriptionSucceedsWithSystemContract() public view {
        assertTrue(rsc.subscriptionConfigured());
    }

    function _log() internal view returns (IReactive.LogRecord memory) {
        return IReactive.LogRecord({
            chain_id: 1301,
            _contract: hook,
            topic_0: rsc.SWAP_PRICE_UPDATE_TOPIC(),
            topic_1: uint256(poolId),
            topic_2: 0,
            topic_3: 0,
            data: abi.encode(uint160(1e18), block.timestamp),
            block_number: block.number,
            op_code: 0,
            block_hash: 0,
            tx_hash: 0,
            log_index: 0
        });
    }
}

contract MockReactiveSystemOk {
    receive() external payable {}

    function subscribe(uint256, address, uint256, uint256, uint256, uint256) external pure {}
}
