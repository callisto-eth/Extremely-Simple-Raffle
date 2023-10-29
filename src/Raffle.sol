// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

/// @title Proveably Random Raffle Contract
/// @author Gizem
/// @notice This Contract creates a Simple Raffle
/// @dev Implements Chainlink VRF2

import {VRFCoordinatorV2Interface} from "chainlink-brownie-contracts/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";

import {VRFConsumerBaseV2} from "chainlink-brownie-contracts/contracts/src/v0.8/VRFConsumerBaseV2.sol";

contract Raffle is VRFConsumerBaseV2 {
    // Errors

    error NotEnoughEthSent();
    error Raffle__TransferFail();
    error Raffle_RaffleNotOpen();
    error Raffle_UpkeepNotNeeded(
        uint256 currentBalance,
        uint256 numPlayers,
        uint256 raffleState
    );

    // Enums

    enum RaffleState {
        OPEN,
        CALCULATING
    }

    // Constants

    uint16 private constant REQUEST_CONFIRMATION = 3;
    uint32 private constant NUM_WORDS = 1;

    // State Variable

    uint256 private immutable i_raffleInterval; /// @dev Duration of Lottery in Seconds
    uint256 private immutable i_entryFee;
    uint256 private s_lastTimeStamp;
    address payable[] private s_rafflePlayers;
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    bytes32 private immutable i_gasLane;
    uint64 private immutable i_subscriptionID;
    uint32 private immutable i_callbackGasLimit;
    address private s_lottoWinner;
    RaffleState private s_raffleState;

    // Events

    event EnterRaffle(address indexed playerAddress);
    event PickedWinner(address indexed pickedWinner);
    event RequestedRaffleWinner(uint256 indexed requestId);

    constructor(
        uint256 _entryFee,
        uint256 _raffleInterval,
        address _vrfCoordinator,
        bytes32 _gasLane,
        uint64 _subsciptionID,
        uint32 _callbackGasLimit
    ) VRFConsumerBaseV2(_vrfCoordinator) {
        i_entryFee = _entryFee;
        i_raffleInterval = _raffleInterval;
        s_lastTimeStamp = block.timestamp;
        i_vrfCoordinator = VRFCoordinatorV2Interface(_vrfCoordinator);
        i_gasLane = _gasLane;
        i_subscriptionID = _subsciptionID;
        i_callbackGasLimit = _callbackGasLimit;
        s_raffleState = RaffleState.OPEN;
    }

    function enterRaffle() external payable {
        if (msg.value < i_entryFee) {
            revert NotEnoughEthSent();
        }

        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle_RaffleNotOpen();
        }

        s_rafflePlayers.push(payable(msg.sender));
        emit EnterRaffle(msg.sender);
    }

    function checkUpkeep(
        bytes memory /* checkData */
    ) public view returns (bool upkeepNeeded, bytes memory /* performData */) {
        bool timePassed = (block.timestamp - s_lastTimeStamp) >=
            i_raffleInterval;

        bool isOpen = RaffleState.OPEN == s_raffleState;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_rafflePlayers.length > 0;
        upkeepNeeded = (isOpen && hasBalance && hasPlayers && timePassed);
        return (upkeepNeeded, "0x0");
    }

    function performUpkeep(bytes calldata /* performData */) external {
        (bool upkeepNeeded, ) = checkUpkeep("");

        if (!upkeepNeeded) {
            revert Raffle_UpkeepNotNeeded(
                address(this).balance,
                s_rafflePlayers.length,
                uint256(s_raffleState)
            );
        }

        s_raffleState = RaffleState.CALCULATING;

        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane,
            i_subscriptionID,
            REQUEST_CONFIRMATION,
            i_callbackGasLimit,
            NUM_WORDS
        );

        emit RequestedRaffleWinner(requestId);
    }

    function fulfillRandomWords(
        uint256 /* requestId */,
        uint256[] memory randomWords
    ) internal override {
        uint256 indexOfWinner = randomWords[0] % s_rafflePlayers.length;
        address payable recentWinner = s_rafflePlayers[indexOfWinner];

        s_lottoWinner = recentWinner;
        s_raffleState = RaffleState.OPEN;

        s_rafflePlayers = new address payable[](0);
        s_lastTimeStamp = block.timestamp;

        (bool successVal, ) = recentWinner.call{value: address(this).balance}(
            ""
        );

        if (!successVal) {
            revert Raffle__TransferFail();
        }

        emit PickedWinner(recentWinner);
    }

    function getEntranceFee() external view returns (uint) {
        return i_entryFee;
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getPlayer(uint256 _indexOfPlayer) external view returns (address) {
        return s_rafflePlayers[_indexOfPlayer];
    }

    function getRecentWinner() external view returns (address) {
        return s_lottoWinner;
    }

    function getLastTimeStamp() external view returns (uint256) {
        return s_lastTimeStamp;
    }

    function getLengthOfPlayers() external view returns (uint256) {
        return s_rafflePlayers.length;
    }
}
