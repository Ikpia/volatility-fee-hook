// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Script, console2} from "forge-std/Script.sol";
import {VolatilityFeeRSC} from "../src/rsc/VolatilityFeeRSC.sol";

contract DeployVolatilityFeeRSC is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        uint256 destinationChainId = vm.envUint("DESTINATION_CHAIN_ID");
        address hook = vm.envAddress("VOLATILITY_FEE_HOOK");
        uint64 callbackGasLimit = uint64(vm.envOr("VOL_CALLBACK_GAS_LIMIT", uint256(50_000)));
        uint256 volLow = vm.envOr("VOL_THRESHOLD_LOW", uint256(1e15));
        uint256 volHigh = vm.envOr("VOL_THRESHOLD_HIGH", uint256(5e15));
        uint256 minSwaps = vm.envOr("VOL_MIN_SWAPS_BEFORE_UPDATE", uint256(3));

        vm.startBroadcast(deployerKey);
        VolatilityFeeRSC rsc =
            new VolatilityFeeRSC(destinationChainId, hook, callbackGasLimit, volLow, volHigh, minSwaps);
        vm.stopBroadcast();

        console2.log("Destination chain", destinationChainId);
        console2.log("Hook", hook);
        console2.log("VolatilityFeeRSC", address(rsc));
        console2.log("Callback sender", rsc.CALLBACK_SENDER());
        console2.log("Subscription configured", rsc.subscriptionConfigured());
    }
}
