// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {IReactive} from "reactive-lib/interfaces/IReactive.sol";

interface IReactiveSubscriptionService {
    function subscribe(
        uint256 chainId,
        address contractAddress,
        uint256 topic0,
        uint256 topic1,
        uint256 topic2,
        uint256 topic3
    ) external;
}

contract VolatilityFeeCallbackRSC is IReactive {
    error OnlySubscriptionAdmin();
    error SubscriptionFailed();
    error PayFailed();

    uint256 internal constant REACTIVE_IGNORE = 0xa65f96fc951c35ead38878e0f0b7a3c744a6f5ccc1476b313353ce31712313ad;
    address internal constant SERVICE = 0x0000000000000000000000000000000000fffFfF;

    uint256 public constant SWAP_PRICE_UPDATE_TOPIC = uint256(keccak256("SwapPriceUpdate(bytes32,uint160,uint256)"));

    uint256 public immutable DESTINATION_CHAIN_ID;
    address public immutable HOOK_ADDRESS;
    uint64 public immutable CALLBACK_GAS_LIMIT;
    address public immutable SUBSCRIPTION_ADMIN;
    address public immutable CALLBACK_SENDER;
    uint24 public immutable CALLBACK_FEE;

    bool public subscriptionConfigured;

    event SubscriptionConfigured(uint256 indexed destinationChainId, address indexed hook, uint256 topic0);
    event SubscriptionUnavailable();
    event FeeCallbackQueued(bytes32 indexed poolId, uint24 newFee, address hook);

    constructor(uint256 destinationChainId, address hookAddress, uint64 callbackGasLimit, uint24 callbackFee) payable {
        DESTINATION_CHAIN_ID = destinationChainId;
        HOOK_ADDRESS = hookAddress;
        CALLBACK_GAS_LIMIT = callbackGasLimit;
        SUBSCRIPTION_ADMIN = msg.sender;
        CALLBACK_SENDER = msg.sender;
        CALLBACK_FEE = callbackFee;
        _configureSubscription(false);
    }

    function configureSubscription() external {
        if (msg.sender != SUBSCRIPTION_ADMIN) revert OnlySubscriptionAdmin();
        _configureSubscription(true);
    }

    function react(LogRecord calldata log) external {
        bytes32 poolId = bytes32(log.topic_1);
        bytes memory payload = abi.encodeWithSignature(
            "updateFeeFromReactive(address,bytes32,uint24)", CALLBACK_SENDER, poolId, CALLBACK_FEE
        );
        emit FeeCallbackQueued(poolId, CALLBACK_FEE, HOOK_ADDRESS);
        emit Callback(DESTINATION_CHAIN_ID, HOOK_ADDRESS, CALLBACK_GAS_LIMIT, payload);
    }

    function pay(uint256 amount) external {
        if (msg.sender != SERVICE) return;
        (bool ok,) = payable(SERVICE).call{value: amount}("");
        if (!ok) revert PayFailed();
    }

    receive() external payable {}

    function _configureSubscription(bool revertOnFailure) internal {
        try IReactiveSubscriptionService(SERVICE).subscribe(
            DESTINATION_CHAIN_ID, HOOK_ADDRESS, SWAP_PRICE_UPDATE_TOPIC, REACTIVE_IGNORE, REACTIVE_IGNORE, REACTIVE_IGNORE
        ) {
            subscriptionConfigured = true;
            emit SubscriptionConfigured(DESTINATION_CHAIN_ID, HOOK_ADDRESS, SWAP_PRICE_UPDATE_TOPIC);
        } catch {
            if (revertOnFailure) revert SubscriptionFailed();
            emit SubscriptionUnavailable();
        }
    }
}
