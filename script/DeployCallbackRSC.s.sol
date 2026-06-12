// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Script, console2} from "forge-std/Script.sol";
import {VolatilityFeeCallbackRSC} from "../src/rsc/VolatilityFeeCallbackRSC.sol";

contract DeployVolatilityFeeCallbackRSC is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        uint256 destinationChainId = vm.envUint("DESTINATION_CHAIN_ID");
        address hook = vm.envAddress("VOLATILITY_FEE_HOOK");
        uint64 callbackGasLimit = uint64(vm.envOr("VOL_CALLBACK_GAS_LIMIT", uint256(120_000)));
        uint24 callbackFee = uint24(vm.envOr("VOL_CALLBACK_FEE", uint256(3000)));

        vm.startBroadcast(deployerKey);
        VolatilityFeeCallbackRSC rsc =
            new VolatilityFeeCallbackRSC(destinationChainId, hook, callbackGasLimit, callbackFee);
        vm.stopBroadcast();

        console2.log("Destination chain", destinationChainId);
        console2.log("Hook", hook);
        console2.log("VolatilityFeeCallbackRSC", address(rsc));
        console2.log("Callback sender", rsc.CALLBACK_SENDER());
        console2.log("Callback fee", rsc.CALLBACK_FEE());
        console2.log("Subscription configured", rsc.subscriptionConfigured());
    }
}
