// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "../../lib/forge-std/src/Test.sol";
import {DeployLottery} from "../../script/DeployLottery.s.sol";
import {Lottery} from "../../src/Lottery.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "../../script/Interactions.s.sol";
import {Vm} from "../../lib/forge-std/src/Vm.sol";

contract InteractionsTest is Test {
    DeployLottery private deployLottery;
    Lottery private lottery;
    HelperConfig private helperConfig;

    address _user = makeAddr("user");
    uint256 _USER_AMOUNT = 10 ether;
    address vrfCoordinator;
    uint64 subscriptionId;
    uint256 deployerKey;
    address linkToken;

    function setUp() public {
        deployLottery = new DeployLottery();
        (lottery, helperConfig) = deployLottery.run();

        (, , vrfCoordinator, , , , , deployerKey) = helperConfig
            .activeNetworkConfig();

        vm.deal(_user, _USER_AMOUNT);
    }

    function testUserCanCreateSubscription() public {
        CreateSubscription createSubscription = new CreateSubscription();
        uint64 subId = createSubscription.createSubscriptionUsingConfig();
        assert(subId > 0);
    }

    function testUserCanFundSubscription() public {
        CreateSubscription createSubscription = new CreateSubscription();
        uint64 subId = createSubscription.createSubscription(
            vrfCoordinator,
            deployerKey
        );

        FundSubscription fundSubscription = new FundSubscription();

        vm.recordLogs();
        fundSubscription.fundSubscription(
            vrfCoordinator,
            subId,
            linkToken,
            deployerKey
        );
        Vm.Log[] memory vmLogs = vm.getRecordedLogs();
        bytes32 emittedMessaged = vmLogs[0].topics[1];

        if (block.chainid == 31337) {
            assertEq(subId, uint256(emittedMessaged));
        } else {
            assertEq(uint256(uint160(_user)), uint256(emittedMessaged));
        }
    }

    function testCanAddConsumerToSubscription() public {
        CreateSubscription createSubscription = new CreateSubscription();
        uint64 subId = createSubscription.createSubscription(
            vrfCoordinator,
            deployerKey
        );

        FundSubscription fundSubscription = new FundSubscription();
        fundSubscription.fundSubscription(
            vrfCoordinator,
            subId,
            linkToken,
            deployerKey
        );

        AddConsumer addConsumer = new AddConsumer();
        vm.recordLogs();
        addConsumer.addConsumer(
            vrfCoordinator,
            subId,
            address(lottery),
            deployerKey
        );
        Vm.Log[] memory vmLogs = vm.getRecordedLogs();
        bytes32 emittedMessaged = vmLogs[0].topics[1];

        assertEq(subId, uint256(emittedMessaged));
    }
}
