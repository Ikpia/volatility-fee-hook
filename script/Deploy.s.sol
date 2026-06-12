// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Script, console2} from "forge-std/Script.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {HookMiner} from "v4-hooks-public/src/utils/HookMiner.sol";
import {VolatilityFeeHook} from "../src/VolatilityFeeHook.sol";

contract DeployVolatilityFeeHook is Script {
    address internal constant CREATE2_DEPLOYER = 0x4e59b44847b379578588920cA78FbF26c0B4956C;

    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);
        address poolManager = vm.envAddress("POOL_MANAGER");
        address callbackProxy = vm.envAddress("CALLBACK_PROXY");
        address reactiveSender = vm.envOr("REACTIVE_SENDER", deployer);
        uint24 feeLow = uint24(vm.envOr("VOL_FEE_LOW", uint256(500)));
        uint24 feeMedium = uint24(vm.envOr("VOL_FEE_MEDIUM", uint256(3000)));
        uint24 feeHigh = uint24(vm.envOr("VOL_FEE_HIGH", uint256(10_000)));
        uint256 volLow = vm.envOr("VOL_THRESHOLD_LOW", uint256(1e15));
        uint256 volHigh = vm.envOr("VOL_THRESHOLD_HIGH", uint256(5e15));

        uint160 flags = uint160(Hooks.AFTER_INITIALIZE_FLAG | Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG);
        bytes memory args =
            abi.encode(IPoolManager(poolManager), callbackProxy, reactiveSender, feeLow, feeMedium, feeHigh, volLow, volHigh);
        (address expectedHook, bytes32 salt) =
            HookMiner.find(CREATE2_DEPLOYER, flags, type(VolatilityFeeHook).creationCode, args);

        vm.startBroadcast(deployerKey);
        VolatilityFeeHook hook = new VolatilityFeeHook{salt: salt}(
            IPoolManager(poolManager), callbackProxy, reactiveSender, feeLow, feeMedium, feeHigh, volLow, volHigh
        );
        vm.stopBroadcast();

        require(address(hook) == expectedHook, "HOOK_ADDRESS_MISMATCH");
        console2.log("Deployer", deployer);
        console2.log("PoolManager", poolManager);
        console2.log("Callback proxy", callbackProxy);
        console2.log("Reactive sender", reactiveSender);
        console2.log("VolatilityFeeHook", address(hook));
        console2.log("Fee low/medium/high", feeLow, feeMedium, feeHigh);
        console2.log("Vol thresholds", volLow, volHigh);
    }
}
