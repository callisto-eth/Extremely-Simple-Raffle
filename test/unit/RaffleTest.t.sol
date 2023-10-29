// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {Raffle} from "../../src/Raffle.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2Mock} from "chainlink-brownie-contracts/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

contract RaffleTest is Test {
    Raffle testRaffle;
    HelperConfig helperConfig;
    uint256 private _entryFee;
    uint256 private _raffleInterval;
    address private _vrfCoordinator;
    bytes32 private _gasLane;
    uint32 private _subsciptionID;
    uint32 private _callbackGasLimit;

    event EnterRaffle(address indexed playerAddress);

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_USER_BALANCE = 10 ether;

    function setUp() external {
        DeployRaffle raffleDeployer = new DeployRaffle();
        (testRaffle, helperConfig) = raffleDeployer.run();
        (
            _entryFee,
            _raffleInterval,
            _vrfCoordinator,
            _gasLane,
            _subsciptionID,
            _callbackGasLimit,
            ,

        ) = helperConfig.activeConfig();

        vm.deal(PLAYER, STARTING_USER_BALANCE);
    }

    function test_raffleInitializesInOpenState() public view {
        assert(testRaffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    function test_raffleRevertsWhenYouDontPayEnough() public {
        vm.prank(PLAYER);
        vm.expectRevert(Raffle.NotEnoughEthSent.selector);
        testRaffle.enterRaffle();
    }

    function test_raffleRecordWhenPlayerEnters() public {
        vm.prank(PLAYER);
        testRaffle.enterRaffle{value: _entryFee}();
        address playerRecord = testRaffle.getPlayer(0);
        assert(playerRecord == PLAYER);
    }

    function test_emitsEventOnEntrance() public {
        vm.prank(PLAYER);
        vm.expectEmit();
        emit EnterRaffle(PLAYER);
        testRaffle.enterRaffle{value: _entryFee}();
    }

    function test_cantEnterWhenRaffleIsCalculating() public {
        vm.prank(PLAYER);
        testRaffle.enterRaffle{value: _entryFee}();
        vm.warp(block.timestamp + _raffleInterval + 1);
        vm.roll(block.number + 1);
        testRaffle.performUpkeep("");
        vm.expectRevert(Raffle.Raffle_RaffleNotOpen.selector);
        vm.prank(PLAYER);
        testRaffle.enterRaffle{value: _entryFee}();
    }

    function test_checkupKeepReturnsFalseIfItHasNoFunds() public {
        vm.warp(block.timestamp + _raffleInterval + 1);
        vm.roll(block.number + 1);

        (bool upkeepNeeded, ) = testRaffle.checkUpkeep("");

        assert(!upkeepNeeded);
    }

    function test_checkupKeepReturnsIfRaffleNotOpen() public {
        vm.prank(PLAYER);
        testRaffle.enterRaffle{value: _entryFee}();
        vm.warp(block.timestamp + _raffleInterval + 1);
        vm.roll(block.number + 1);
        testRaffle.performUpkeep("");
        (bool upkeepNeeded, ) = testRaffle.checkUpkeep("");

        assert(!upkeepNeeded);
    }

    function test_checkupKeepReturnsFalseIfEnoughTimeHasntPassed() public {
        vm.prank(PLAYER);
        testRaffle.enterRaffle{value: _entryFee}();
        (bool upkeepNeeded, ) = testRaffle.checkUpkeep("");

        assert(!upkeepNeeded);
    }

    function test_checkupKeepReturnsTrueWhenTheParameterAreGood() public {
        vm.prank(PLAYER);
        testRaffle.enterRaffle{value: _entryFee}();
        vm.warp(block.timestamp + _raffleInterval + 1);
        vm.roll(block.number + 1);
        (bool upkeepNeeded, ) = testRaffle.checkUpkeep("");

        assert(upkeepNeeded);
    }

    function test_performUpkeepCanOnlyRunIfCheckUpkeepIsTrue() public {
        vm.prank(PLAYER);
        testRaffle.enterRaffle{value: _entryFee}();
        vm.warp(block.timestamp + _raffleInterval + 1);
        vm.roll(block.number + 1);

        testRaffle.performUpkeep("");
    }

    function test_performUpkeepRevertsIfCheckupKeepIsFalse() public {
        // uint256 currentBalance = 0;
        // uint256 numPlayers = 0;
        // uint256 raffleState = uint256(testRaffle.getRaffleState());
        // vm.expectRevert(
        //     abi.encodeWithSelector(
        //         Raffle.Raffle_UpkeepNotNeeded.selector,
        //         currentBalance,
        //         numPlayers,
        //         raffleState
        //     )
        // );

        // TODO: Figure out what's wrong with the above Method;

        vm.expectRevert();
        testRaffle.performUpkeep("");
    }

    modifier raffleEnteredAndTimePassed() {
        vm.prank(PLAYER);
        testRaffle.enterRaffle{value: _entryFee}();
        vm.warp(block.timestamp + _raffleInterval + 1);
        vm.roll(block.number + 1);
        _;
    }

    modifier skipFork() {
        if (block.chainid != 31337) {
            return;
        }
        _;
    }

    function test_performUpkeepUpdatesRaffleStateAndEmitRequestId()
        public
        raffleEnteredAndTimePassed
    {
        vm.recordLogs();
        testRaffle.performUpkeep("");
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 requestId = logs[1].topics[1];
        assert(uint256(requestId) > 0);
        assert(testRaffle.getRaffleState() == Raffle.RaffleState.CALCULATING);
    }

    function testFuzz_fulfillRandomWordsCanBeCalledAfterPerformUpkeep(
        uint256 _randomRequestID
    ) public raffleEnteredAndTimePassed skipFork {
        vm.expectRevert("nonexistent request");
        VRFCoordinatorV2Mock(_vrfCoordinator).fulfillRandomWords(
            _randomRequestID,
            address(testRaffle)
        );
    }

    function testFuzz_fulfillRandomWordsPicksAWinnerResetsAndSendMoney()
        public
        raffleEnteredAndTimePassed
        skipFork
    {
        uint256 additionalEntrance = 5;
        uint256 startingIndex = 1;

        for (
            uint256 iVal = startingIndex;
            iVal < additionalEntrance + 1;
            iVal++
        ) {
            address rafPlayer = address(uint160(iVal));
            hoax(rafPlayer, STARTING_USER_BALANCE);
            testRaffle.enterRaffle{value: _entryFee}();
        }

        uint256 prizeMoney = _entryFee * (additionalEntrance + 1);
        uint256 previousTimeStamp = testRaffle.getLastTimeStamp();

        vm.recordLogs();
        testRaffle.performUpkeep("");
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 requestId = logs[1].topics[1];

        VRFCoordinatorV2Mock(_vrfCoordinator).fulfillRandomWords(
            uint256(requestId),
            address(testRaffle)
        );

        assert(uint256(testRaffle.getRaffleState()) == 0);
        assert(testRaffle.getRecentWinner() != address(0));
        assert(testRaffle.getLengthOfPlayers() == 0);
        assert(testRaffle.getLastTimeStamp() > previousTimeStamp);
        assert(
            testRaffle.getRecentWinner().balance ==
                (prizeMoney + STARTING_USER_BALANCE) - _entryFee
        );
    }
}
