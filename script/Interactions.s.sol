// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "../lib/forge-std/src/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";
import {DevOpsTools} from "../lib/foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is Script {
    function createSubscriptionUsingConfig() public returns (uint64) {
        HelperConfig helperConfig = new HelperConfig();

        (, , address vrfCoordinator, , , , , uint256 deployerKey) = helperConfig
            .activeNetworkConfig();
        return createSubscription(vrfCoordinator, deployerKey);
    }

    function createSubscription(
        address _vrfCoordinator,
        uint256 _deployerKey
    ) public returns (uint64) {
        console.log("Creating subscription on block chain ID: ", block.chainid);

        vm.startBroadcast(_deployerKey);
        uint64 subId = VRFCoordinatorV2Mock(_vrfCoordinator)
            .createSubscription();
        vm.stopBroadcast();

        console.log("subId: ", subId);
        return subId;
    }

    function run() external returns (uint64) {
        return createSubscriptionUsingConfig();
    }
}

contract FundSubscription is Script {
    uint96 public constant LINK_AMOUNT = 3 ether;

    function fundSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();

        (
            ,
            ,
            address vrfCoordinator,
            ,
            uint64 subId,
            ,
            address link,
            uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();
        fundSubscription(vrfCoordinator, subId, link, deployerKey);
    }

    function fundSubscription(
        address _vrfCoordinator,
        uint64 _subId,
        address _link,
        uint256 _deployerKey
    ) public {
        console.log("Funding subscription on block chain ID: ", block.chainid);

        if (block.chainid == 31337) {
            vm.startBroadcast(_deployerKey);
            VRFCoordinatorV2Mock(_vrfCoordinator).fundSubscription(
                _subId,
                LINK_AMOUNT
            );
            vm.stopBroadcast();
        } else {
            vm.startBroadcast(_deployerKey);
            LinkToken(_link).transferAndCall(
                _vrfCoordinator,
                LINK_AMOUNT,
                abi.encode(_subId)
            );
            vm.stopBroadcast();
        }
    }

    function run() external {
        fundSubscriptionUsingConfig();
    }
}

contract AddConsumer is Script {
    function addConsumer(
        address vrfCoordinator,
        uint64 subId,
        address mostRecentlyDeployed,
        uint256 deployerKey
    ) public {
        console.log("Adding consumer on block chain ID: ", block.chainid);

        vm.startBroadcast(deployerKey);
        VRFCoordinatorV2Mock(vrfCoordinator).addConsumer(
            subId,
            mostRecentlyDeployed
        );
        vm.stopBroadcast();
    }

    function addConsumerUsingConfig(address mostRecentlyDeployed) public {
        HelperConfig helperConfig = new HelperConfig();

        (
            ,
            ,
            address vrfCoordinator,
            ,
            uint64 subId,
            ,
            ,
            uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();
        addConsumer(vrfCoordinator, subId, mostRecentlyDeployed, deployerKey);
    }

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment(
            "Lottery",
            block.chainid
        );
        addConsumerUsingConfig(mostRecentlyDeployed);
    }
}
