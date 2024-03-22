// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*
├── Pragma (version)
├── Imports
├── Events
├── Errors
├── Interfaces
├── Libraries
└── Contracts
    ├── Type declarations
    ├── State variables
    ├── Events
    ├── Errors
    ├── Modifiers
    └── Functions
        ├── Constructor
        ├── Receive function (if exists)
        ├── Fallback function (if exists)
        ├── External
        ├── Public
        ├── Internal
        └── Private
*/

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

/**
 * @title Lottery
 * @author Boris Kolev
 * @dev A contract which is used to deploy the Lottery contract implementing ChainLink VRF
 */
contract Lottery is VRFConsumerBaseV2 {
    /* Type declarations */
    enum LotteryStates {
        OPEN,
        CLOSED
    }

    /* State Variables */
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    address[] private s_players;
    uint256 private s_lastTimeStamp;

    uint256 private immutable i_entranceFee;
    uint256 private immutable i_interval;
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    bytes32 private immutable i_gasLane;
    uint64 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;
    address private s_recentWinner;
    LotteryStates private s_lotteryState;

    /* Events */
    event EnterLottery(address indexed _player);
    event PickedWinner(address indexed _winner);
    event RequestedLotteryWinner(uint256 indexed _requestId);
    event RequestId(uint256 indexed _requestId);

    /* Errors */
    error Lottery_NotEnoughEtherToEnter();
    error Lottery_CouldNotPayWinner();
    error Lottery_LotteryClosed();
    error Lottery_UpkeepNotNeeded();

    constructor(
        uint256 _entranceFee,
        uint256 _interval,
        address _vrfCoordinator,
        bytes32 _gasLane,
        uint64 _subscriptionId,
        uint32 _callbackGasLimit
    ) VRFConsumerBaseV2(_vrfCoordinator) {
        i_entranceFee = _entranceFee;
        i_interval = _interval;
        i_vrfCoordinator = VRFCoordinatorV2Interface(_vrfCoordinator);
        i_gasLane = _gasLane;
        i_subscriptionId = _subscriptionId;
        i_callbackGasLimit = _callbackGasLimit;
        s_lastTimeStamp = block.timestamp;
        s_lotteryState = LotteryStates.OPEN;
    }

    function enterLottery() external payable {
        if (msg.value < i_entranceFee) {
            revert Lottery_NotEnoughEtherToEnter();
        }
        if (s_lotteryState == LotteryStates.CLOSED) {
            revert Lottery_LotteryClosed();
        }
        s_players.push(msg.sender);
        emit EnterLottery(msg.sender);
    }

    function performUpkeep(bytes calldata /* performData */) external {
        (bool upkeepNeeded, ) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Lottery_UpkeepNotNeeded();
        }
        s_lotteryState = LotteryStates.CLOSED;

        uint256 s_requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane, // gas lane
            i_subscriptionId, // CL sub ID
            REQUEST_CONFIRMATIONS, // ~3
            i_callbackGasLimit, // 200000
            NUM_WORDS // 1
        );
        emit RequestId(s_requestId);
    }

    /**
     * @dev This is a Chainlink function that is called when the Chainlink VRF
     * node has fulfilled the request. It will be called by the VRF Coordinator.
     *
     */
    function checkUpkeep(
        bytes memory /* checkData */
    ) public view returns (bool upkeepNeeded, bytes memory /* performData */) {
        bool timePassed = block.timestamp - s_lastTimeStamp >= i_interval;
        bool isOpen = s_lotteryState == LotteryStates.OPEN;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;
        upkeepNeeded = (timePassed && isOpen && hasBalance && hasPlayers);
        return (upkeepNeeded, "");
    }

    function fulfillRandomWords(
        uint256,
        /* requestId */ uint256[] memory _randomWords
    ) internal override {
        uint256 winnerIndex = _randomWords[0] % s_players.length;
        address winner = s_players[winnerIndex];
        s_recentWinner = winner;
        s_players = new address[](0);
        s_lastTimeStamp = block.timestamp;
        s_lotteryState = LotteryStates.OPEN;
        emit PickedWinner(winner);
        (bool success, ) = payable(winner).call{value: address(this).balance}(
            ""
        );
        if (!success) {
            revert Lottery_CouldNotPayWinner();
        }
    }

    /* Getters */
    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getLotteryState() external view returns (LotteryStates) {
        return s_lotteryState;
    }

    function getPlayers() external view returns (address[] memory) {
        return s_players;
    }

    function getPlayer(uint256 _index) external view returns (address) {
        return s_players[_index];
    }

    function getRecentWinner() external view returns (address) {
        return s_recentWinner;
    }

    function getLastTimeStamp() external view returns (uint256) {
        return s_lastTimeStamp;
    }
}
