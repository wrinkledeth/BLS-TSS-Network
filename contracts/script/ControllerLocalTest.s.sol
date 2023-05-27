// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/Controller.sol";
import "../src/interfaces/IControllerOwner.sol";
import "../src/Adapter.sol";
import "../src/interfaces/IAdapterOwner.sol";
import "./ArpaLocalTest.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Staking, ArpaTokenInterface} from "Staking-v0.1/Staking.sol";

contract ControllerLocalTestScript is Script {
    uint256 deployerPrivateKey = vm.envUint("ADMIN_PRIVATE_KEY");

    uint256 disqualifiedNodePenaltyAmount = vm.envUint("DISQUALIFIED_NODE_PENALTY_AMOUNT");
    uint256 defaultNumberOfCommitters = vm.envUint("DEFAULT_NUMBER_OF_COMMITTERS");
    uint256 defaultDkgPhaseDuration = vm.envUint("DEFAULT_DKG_PHASE_DURATION");
    uint256 groupMaxCapacity = vm.envUint("GROUP_MAX_CAPACITY");
    uint256 idealNumberOfGroups = vm.envUint("IDEAL_NUMBER_OF_GROUPS");
    uint256 pendingBlockAfterQuit = vm.envUint("PENDING_BLOCK_AFTER_QUIT");
    uint256 dkgPostProcessReward = vm.envUint("DKG_POST_PROCESS_REWARD");
    uint256 last_output = vm.envUint("LAST_OUTPUT");

    uint16 minimumRequestConfirmations = uint16(vm.envUint("MINIMUM_REQUEST_CONFIRMATIONS"));
    uint32 maxGasLimit = uint32(vm.envUint("MAX_GAS_LIMIT"));
    uint32 gasAfterPaymentCalculation = uint32(vm.envUint("GAS_AFTER_PAYMENT_CALCULATION"));
    uint32 gasExceptCallback = uint32(vm.envUint("GAS_EXCEPT_CALLBACK"));
    uint256 signatureTaskExclusiveWindow = vm.envUint("SIGNATURE_TASK_EXCLUSIVE_WINDOW");
    uint256 rewardPerSignature = vm.envUint("REWARD_PER_SIGNATURE");
    uint256 committerRewardPerSignature = vm.envUint("COMMITTER_REWARD_PER_SIGNATURE");

    uint32 fulfillmentFlatFeeEthPPMTier1 = uint32(vm.envUint("FULFILLMENT_FLAT_FEE_ARPA_PPM_TIER1"));
    uint32 fulfillmentFlatFeeEthPPMTier2 = uint32(vm.envUint("FULFILLMENT_FLAT_FEE_ARPA_PPM_TIER2"));
    uint32 fulfillmentFlatFeeEthPPMTier3 = uint32(vm.envUint("FULFILLMENT_FLAT_FEE_ARPA_PPM_TIER3"));
    uint32 fulfillmentFlatFeeEthPPMTier4 = uint32(vm.envUint("FULFILLMENT_FLAT_FEE_ARPA_PPM_TIER4"));
    uint32 fulfillmentFlatFeeEthPPMTier5 = uint32(vm.envUint("FULFILLMENT_FLAT_FEE_ARPA_PPM_TIER5"));
    uint24 reqsForTier2 = uint24(vm.envUint("REQS_FOR_TIER2"));
    uint24 reqsForTier3 = uint24(vm.envUint("REQS_FOR_TIER3"));
    uint24 reqsForTier4 = uint24(vm.envUint("REQS_FOR_TIER4"));
    uint24 reqsForTier5 = uint24(vm.envUint("REQS_FOR_TIER5"));

    uint16 flatFeePromotionGlobalPercentage = uint16(vm.envUint("FLAT_FEE_PROMOTION_GLOBAL_PERCENTAGE"));
    bool isFlatFeePromotionEnabledPermanently = vm.envBool("IS_FLAT_FEE_PROMOTION_ENABLED_PERMANENTLY");
    uint256 flatFeePromotionStartTimestamp = vm.envUint("FLAT_FEE_PROMOTION_START_TIMESTAMP");
    uint256 flatFeePromotionEndTimestamp = vm.envUint("FLAT_FEE_PROMOTION_END_TIMESTAMP");

    uint256 initialMaxPoolSize = vm.envUint("INITIAL_MAX_POOL_SIZE");
    uint256 initialMaxCommunityStakeAmount = vm.envUint("INITIAL_MAX_COMMUNITY_STAKE_AMOUNT");
    uint256 minCommunityStakeAmount = vm.envUint("MIN_COMMUNITY_STAKE_AMOUNT");
    uint256 operatorStakeAmount = vm.envUint("OPERATOR_STAKE_AMOUNT");
    uint256 minInitialOperatorCount = vm.envUint("MIN_INITIAL_OPERATOR_COUNT");
    uint256 minRewardDuration = vm.envUint("MIN_REWARD_DURATION");
    uint256 delegationRateDenominator = vm.envUint("DELEGATION_RATE_DENOMINATOR");
    uint256 unstakeFreezingDuration = vm.envUint("UNSTAKE_FREEZING_DURATION");

    function setUp() public {}

    function run() external {
        Controller controller;
        ERC1967Proxy adapter;
        Adapter adapter_impl;
        Staking staking;
        IERC20 arpa;

        vm.broadcast(deployerPrivateKey);
        arpa = new Arpa();

        Staking.PoolConstructorParams memory params = Staking.PoolConstructorParams(
            ArpaTokenInterface(address(arpa)),
            initialMaxPoolSize,
            initialMaxCommunityStakeAmount,
            minCommunityStakeAmount,
            operatorStakeAmount,
            minInitialOperatorCount,
            minRewardDuration,
            delegationRateDenominator,
            unstakeFreezingDuration
        );
        vm.broadcast(deployerPrivateKey);
        staking = new Staking(params);

        vm.broadcast(deployerPrivateKey);
        controller = new Controller();

        vm.broadcast(deployerPrivateKey);
        controller.initialize(address(staking), last_output);

        vm.broadcast(deployerPrivateKey);
        adapter_impl = new Adapter();

        vm.broadcast(deployerPrivateKey);
        adapter =
            new ERC1967Proxy(address(adapter_impl),abi.encodeWithSignature("initialize(address)",address(controller)));

        vm.broadcast(deployerPrivateKey);
        IControllerOwner(address(controller)).setControllerConfig(
            address(staking),
            address(adapter),
            operatorStakeAmount,
            disqualifiedNodePenaltyAmount,
            defaultNumberOfCommitters,
            defaultDkgPhaseDuration,
            groupMaxCapacity,
            idealNumberOfGroups,
            pendingBlockAfterQuit,
            dkgPostProcessReward
        );

        vm.broadcast(deployerPrivateKey);
        IAdapterOwner(address(adapter)).setAdapterConfig(
            minimumRequestConfirmations,
            maxGasLimit,
            gasAfterPaymentCalculation,
            gasExceptCallback,
            signatureTaskExclusiveWindow,
            rewardPerSignature,
            committerRewardPerSignature
        );

        vm.broadcast(deployerPrivateKey);
        IAdapterOwner(address(adapter)).setFlatFeeConfig(
            IAdapterOwner.FeeConfig(
                fulfillmentFlatFeeEthPPMTier1,
                fulfillmentFlatFeeEthPPMTier2,
                fulfillmentFlatFeeEthPPMTier3,
                fulfillmentFlatFeeEthPPMTier4,
                fulfillmentFlatFeeEthPPMTier5,
                reqsForTier2,
                reqsForTier3,
                reqsForTier4,
                reqsForTier5
            ),
            flatFeePromotionGlobalPercentage,
            isFlatFeePromotionEnabledPermanently,
            flatFeePromotionStartTimestamp,
            flatFeePromotionEndTimestamp
        );

        vm.broadcast(deployerPrivateKey);
        staking.setController(address(controller));
    }
}
