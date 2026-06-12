// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {AbstractReactive} from "reactive-lib/abstract-base/AbstractReactive.sol";
import {IReactive} from "reactive-lib/interfaces/IReactive.sol";

contract VolatilityFeeRSC is IReactive, AbstractReactive {
    error OnlySubscriptionAdmin();
    error SubscriptionFailed();
    error InvalidConfig();

    uint256 public constant SWAP_PRICE_UPDATE_TOPIC = uint256(keccak256("SwapPriceUpdate(bytes32,uint160,uint256)"));
    uint256 public constant SCALE = 1e18;
    uint256 public constant ALPHA_NUMERATOR = 1;
    uint256 public constant ALPHA_DENOMINATOR = 10;
    uint24 public constant FEE_LOW = 500;
    uint24 public constant FEE_MEDIUM = 3000;
    uint24 public constant FEE_HIGH = 10000;

    uint256 public immutable DESTINATION_CHAIN_ID;
    address public immutable HOOK_ADDRESS;
    uint64 public immutable CALLBACK_GAS_LIMIT;
    address public immutable SUBSCRIPTION_ADMIN;
    address public immutable CALLBACK_SENDER;
    uint256 public immutable VOL_THRESHOLD_LOW;
    uint256 public immutable VOL_THRESHOLD_HIGH;
    uint256 public immutable MIN_SWAPS_BEFORE_UPDATE;

    bool public subscriptionConfigured;
    uint256 public observedSwaps;
    mapping(bytes32 => uint256) public ewmaVol;
    mapping(bytes32 => uint160) public lastSqrtPrice;
    mapping(bytes32 => uint256) public swapsSinceUpdate;
    mapping(bytes32 => uint24) public lastPushedFee;

    event SubscriptionConfigured(
        uint256 indexed destinationChainId,
        address indexed hook,
        uint256 topic0,
        uint256 topic1,
        uint256 topic2,
        uint256 topic3
    );
    event SubscriptionUnavailable();
    event VolatilityObserved(bytes32 indexed poolId, uint256 priceMove, uint256 ewmaVol, uint24 mappedFee);
    event FeeCallbackQueued(bytes32 indexed poolId, uint24 newFee, address hook);

    modifier onlySubscriptionAdmin() {
        if (msg.sender != SUBSCRIPTION_ADMIN) revert OnlySubscriptionAdmin();
        _;
    }

    constructor(
        uint256 destinationChainId,
        address hookAddress,
        uint64 callbackGasLimit,
        uint256 volThresholdLow,
        uint256 volThresholdHigh,
        uint256 minSwapsBeforeUpdate
    ) payable {
        if (hookAddress == address(0) || volThresholdLow >= volThresholdHigh) revert InvalidConfig();
        DESTINATION_CHAIN_ID = destinationChainId;
        HOOK_ADDRESS = hookAddress;
        CALLBACK_GAS_LIMIT = callbackGasLimit;
        SUBSCRIPTION_ADMIN = msg.sender;
        CALLBACK_SENDER = msg.sender;
        VOL_THRESHOLD_LOW = volThresholdLow;
        VOL_THRESHOLD_HIGH = volThresholdHigh;
        MIN_SWAPS_BEFORE_UPDATE = minSwapsBeforeUpdate == 0 ? 3 : minSwapsBeforeUpdate;
        _configureSubscription(false);
    }

    function configureSubscription() external onlySubscriptionAdmin {
        _configureSubscription(true);
    }

    function react(LogRecord calldata log) external vmOnly {
        bytes32 poolId = bytes32(log.topic_1);
        (uint160 sqrtPriceX96,) = abi.decode(log.data, (uint160, uint256));

        uint160 previous = lastSqrtPrice[poolId];
        uint256 priceMove;
        if (previous != 0) {
            priceMove = sqrtPriceX96 > previous ? uint256(sqrtPriceX96 - previous) : uint256(previous - sqrtPriceX96);
            uint256 scaledMove = priceMove * SCALE / uint256(previous);
            ewmaVol[poolId] =
                (ALPHA_NUMERATOR * scaledMove + (ALPHA_DENOMINATOR - ALPHA_NUMERATOR) * ewmaVol[poolId])
                    / ALPHA_DENOMINATOR;
        }

        lastSqrtPrice[poolId] = sqrtPriceX96;
        observedSwaps++;
        swapsSinceUpdate[poolId]++;

        uint24 mappedFee = mapVolToFee(ewmaVol[poolId]);
        emit VolatilityObserved(poolId, priceMove, ewmaVol[poolId], mappedFee);

        if (swapsSinceUpdate[poolId] < MIN_SWAPS_BEFORE_UPDATE) return;
        swapsSinceUpdate[poolId] = 0;

        uint24 pushed = lastPushedFee[poolId];
        if (pushed == 0) pushed = FEE_LOW;
        if (mappedFee == pushed) return;
        lastPushedFee[poolId] = mappedFee;

        bytes memory payload =
            abi.encodeWithSignature("updateFeeFromReactive(address,bytes32,uint24)", CALLBACK_SENDER, poolId, mappedFee);
        emit FeeCallbackQueued(poolId, mappedFee, HOOK_ADDRESS);
        emit Callback(DESTINATION_CHAIN_ID, HOOK_ADDRESS, CALLBACK_GAS_LIMIT, payload);
    }

    function mapVolToFee(uint256 vol) public view returns (uint24) {
        if (vol < VOL_THRESHOLD_LOW) return FEE_LOW;
        if (vol < VOL_THRESHOLD_HIGH) return FEE_MEDIUM;
        return FEE_HIGH;
    }

    function _configureSubscription(bool revertOnFailure) internal {
        if (vm) {
            emit SubscriptionUnavailable();
            return;
        }

        try service.subscribe(
            DESTINATION_CHAIN_ID, HOOK_ADDRESS, SWAP_PRICE_UPDATE_TOPIC, REACTIVE_IGNORE, REACTIVE_IGNORE, REACTIVE_IGNORE
        ) {
            subscriptionConfigured = true;
            emit SubscriptionConfigured(
                DESTINATION_CHAIN_ID,
                HOOK_ADDRESS,
                SWAP_PRICE_UPDATE_TOPIC,
                REACTIVE_IGNORE,
                REACTIVE_IGNORE,
                REACTIVE_IGNORE
            );
        } catch {
            if (revertOnFailure) revert SubscriptionFailed();
            emit SubscriptionUnavailable();
        }
    }
}
