// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Test} from "forge-std/Test.sol";
import {IReactive} from "reactive-lib/interfaces/IReactive.sol";
import {VolatilityFeeRSC} from "../src/rsc/VolatilityFeeRSC.sol";

contract EWMAMathTest is Test {
    VolatilityFeeRSC rsc;
    bytes32 poolId = keccak256("POOL");

    function setUp() public {
        rsc = new VolatilityFeeRSC(84532, address(0xBEEF), 50_000, 1e15, 5e15, 1);
    }

    function testEWMAFirstSwapHasZeroMoveAndTracksPrice() public {
        _react(1e18);
        assertEq(rsc.lastSqrtPrice(poolId), 1e18);
        assertEq(rsc.ewmaVol(poolId), 0);
    }

    function testEWMASpikeThenDecay() public {
        _react(1e18);
        _react(11e17);
        uint256 afterSpike = rsc.ewmaVol(poolId);
        assertEq(afterSpike, 1e16);
        _react(11e17);
        assertEq(rsc.ewmaVol(poolId), afterSpike * 9 / 10);
    }

    function testEWMADownwardMoveUsesAbsoluteReturn() public {
        _react(2e18);
        _react(1e18);
        assertEq(rsc.ewmaVol(poolId), 5e16);
    }

    function testEWMADecayOnStablePrice() public {
        _react(1e18);
        _react(2e18);
        uint256 last = rsc.ewmaVol(poolId);
        for (uint256 i; i < 20; i++) {
            _react(2e18);
            assertLe(rsc.ewmaVol(poolId), last);
            last = rsc.ewmaVol(poolId);
        }
        assertLt(rsc.ewmaVol(poolId), 2e16);
    }

    function testFuzzEWMAStaysBounded(uint160 start, uint160 next) public {
        start = uint160(bound(start, 1e12, type(uint128).max));
        next = uint160(bound(next, 1e12, type(uint128).max));
        _react(start);
        _react(next);
        assertLe(rsc.ewmaVol(poolId), type(uint256).max / 2);
        assertEq(rsc.lastSqrtPrice(poolId), next);
    }

    function _react(uint160 sqrtPriceX96) internal {
        IReactive.LogRecord memory log = IReactive.LogRecord({
            chain_id: 84532,
            _contract: address(0xBEEF),
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
