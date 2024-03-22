// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "../../lib/forge-std/src/Test.sol";
import {DeployLottery} from "../../script/DeployLottery.s.sol";
import {Lottery} from "../../src/Lottery.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Vm} from "../../lib/forge-std/src/Vm.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

contract LotteryTest is Test {
    DeployLottery private deployLottery;
    Lottery private lottery;
    HelperConfig private helperConfig;

    address private _user = makeAddr("user");
    uint256 constant _USER_AMOUNT = 10 ether;
    uint256 private entranceFee;
    uint256 private interval;
    address private vrfCoordinator;
    bytes32 private gasLane;
    uint64 private subscriptionId;
    uint32 private callbackGasLimit;
    address private link;

    event EnterLottery(address indexed _player);

    function setUp() public {
        deployLottery = new DeployLottery();
        (lottery, helperConfig) = deployLottery.run();

        (
            entranceFee,
            interval,
            vrfCoordinator,
            gasLane,
            subscriptionId,
            callbackGasLimit,
            link,

        ) = helperConfig.activeNetworkConfig();

        vm.deal(_user, _USER_AMOUNT);
    }

    function testLotteryIsInOpenStateWhenInitialized() public view {
        assertEq(
            uint256(lottery.getLotteryState()),
            uint256(Lottery.LotteryStates.OPEN)
        );
    }

    function testLotteryRevertOnInsufficientDeposit() public {
        vm.prank(_user);
        vm.expectRevert(Lottery.Lottery_NotEnoughEtherToEnter.selector);
        lottery.enterLottery{value: 0}();
    }

    function testLotteryAddsPlayerOnEnter() public {
        vm.prank(_user);
        lottery.enterLottery{value: entranceFee}();
        assertEq(lottery.getPlayers().length, 1);
        assertEq(lottery.getPlayer(0), _user);
    }

    function testEmitsEventOnEnter() public {
        vm.prank(_user);
        vm.expectEmit(true, false, false, false, address(lottery));

        emit EnterLottery(_user);

        lottery.enterLottery{value: entranceFee}();
    }

    function testCantEnterLotteryWhenClosed() public {
        vm.prank(_user);
        lottery.enterLottery{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        lottery.performUpkeep("");
        vm.expectRevert(Lottery.Lottery_LotteryClosed.selector);
        vm.prank(_user);
        lottery.enterLottery{value: entranceFee}();
    }

    function testCheckUpkeepReturnsFalseIfNoBalance() public {
        vm.prank(_user);
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        (bool upkeepNeeded, ) = lottery.checkUpkeep("");
        assertEq(upkeepNeeded, false);
    }

    function testCheckUpkeepReturnsFalseIfNotOpen() public {
        vm.prank(_user);
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        lottery.enterLottery{value: entranceFee}();
        lottery.performUpkeep("");
        (bool upkeepNeeded, ) = lottery.checkUpkeep("");
        assertEq(upkeepNeeded, false);
    }

    function testCheckUpkeepReturnsFalseIfNoPlayers() public {
        vm.prank(_user);
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        (bool upkeepNeeded, ) = lottery.checkUpkeep("");
        assertEq(upkeepNeeded, false);
    }

    function testCheckUpkeepReturnsFalseIfNotEnoughTimePassed() public {
        vm.prank(_user);
        lottery.enterLottery{value: entranceFee}();
        (bool upkeepNeeded, ) = lottery.checkUpkeep("");
        assertEq(upkeepNeeded, false);
    }

    function testCheckUpkeepReturnsTrueIfAllConditionsMet() public {
        vm.prank(_user);
        lottery.enterLottery{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        (bool upkeepNeeded, ) = lottery.checkUpkeep("");
        assertEq(upkeepNeeded, true);
    }

    function testDoesNotPerformUpkeepIfCheckUpkeepIsFalse() public {
        uint256 currentBalance = 0;
        uint256 numPlayers = 0;
        uint256 lotteryState = 0;

        vm.expectRevert(
            abi.encodeWithSelector(Lottery.Lottery_UpkeepNotNeeded.selector)
        );
        console.log();
        lottery.performUpkeep("");
    }

    function testPerformsUpkeepIfCheckUpkeepIsTrue() public {
        vm.prank(_user);
        lottery.enterLottery{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        lottery.performUpkeep("");
    }

    modifier lotteryUpkeep() {
        vm.prank(_user);
        lottery.enterLottery{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    function testPerformUpkeepUpdatesLotteryStateAndEmitsEvent()
        public
        lotteryUpkeep
    {
        vm.recordLogs();
        lottery.performUpkeep("");
        Vm.Log[] memory vmLogs = vm.getRecordedLogs();
        bytes32 requestId = vmLogs[0].topics[1];

        assert(uint256(requestId) != 0);
    }

    modifier skipFork() {
        if (block.chainid != 31337) {
            return;
        }
        _;
    }

    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(
        uint256 randomReqId
    ) public lotteryUpkeep skipFork {
        vm.expectRevert("nonexistent request");
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            randomReqId,
            address(lottery)
        );
    }

    function testFulfillRandomWordsPicksWinnerResetsAndSendsPrize()
        public
        lotteryUpkeep
        skipFork
    {
        uint256 additionalPlayers = 5;
        uint256 startingIndex = 1;

        address expectedWinner = address(1);

        for (
            uint256 i = startingIndex;
            i < startingIndex + additionalPlayers;
            ++i
        ) {
            address player = address(uint160(i));
            hoax(player, 1 ether);
            lottery.enterLottery{value: entranceFee}();
        }

        uint256 prize = entranceFee * (additionalPlayers + 1);
        uint256 previousTimestamp = lottery.getLastTimeStamp();
        uint256 startingBalance = expectedWinner.balance;

        vm.recordLogs();
        lottery.performUpkeep("");
        Vm.Log[] memory vmLogs = vm.getRecordedLogs();
        bytes32 requestId = vmLogs[1].topics[1];

        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            uint256(requestId),
            address(lottery)
        );

        assert(uint256(lottery.getLotteryState()) == 0);
        assert(lottery.getRecentWinner() != address(0));
        assert(lottery.getPlayers().length == 0);
        assert(previousTimestamp < lottery.getLastTimeStamp());
        assert(lottery.getRecentWinner().balance == prize + startingBalance);
    }
}
