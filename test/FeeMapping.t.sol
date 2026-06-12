// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Test} from "forge-std/Test.sol";
import {VolatilityFeeRSC} from "../src/rsc/VolatilityFeeRSC.sol";

contract FeeMappingTest is Test {
    VolatilityFeeRSC rsc;

    function setUp() public {
        rsc = new VolatilityFeeRSC(84532, address(0xBEEF), 50_000, 1e15, 5e15, 3);
    }

    function testLowVolMapsToLowFee() public view {
        assertEq(rsc.mapVolToFee(0), 500);
        assertEq(rsc.mapVolToFee(1e15 - 1), 500);
    }

    function testBoundaryLowExactMapsToMedium() public view {
        assertEq(rsc.mapVolToFee(1e15), 3000);
    }

    function testMidVolMapsToMediumFee() public view {
        assertEq(rsc.mapVolToFee(3e15), 3000);
        assertEq(rsc.mapVolToFee(5e15 - 1), 3000);
    }

    function testBoundaryHighExactMapsToHigh() public view {
        assertEq(rsc.mapVolToFee(5e15), 10_000);
    }

    function testHighVolMapsToHighFee() public view {
        assertEq(rsc.mapVolToFee(type(uint256).max), 10_000);
    }
}
