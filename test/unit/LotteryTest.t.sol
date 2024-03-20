// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "../../lib/forge-std/src/Test.sol";
import {DeployLottery} from "../../script/DeployLottery.s.sol";
import {Lottery} from "../../src/Lottery.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";

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
            link
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
        vm.expectRevert(Lottery.Raffle_NotEnoughEtherToEnter.selector);
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
        vm.expectRevert(Lottery.Raffle_LotteryClosed.selector);
        vm.prank(_user);
        lottery.enterLottery{value: entranceFee}();
    }
}
