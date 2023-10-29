// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "./Interaction.s.sol";
import {VRFCoordinatorV2Mock} from "chainlink-brownie-contracts/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

contract DeployRaffle is Script {
    function run() external returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        (
            uint256 _entryFee,
            uint256 _raffleInterval,
            address _vrfCoordinator,
            bytes32 _gasLane,
            uint64 _subscriptionID,
            uint32 _callbackGasLimit,
            address _linkToken,
            uint256 _deployerKey
        ) = helperConfig.activeConfig();

        if (_subscriptionID == 0) {
            CreateSubscription createSubscription = new CreateSubscription();
            _subscriptionID = createSubscription.createSubscription(
                _vrfCoordinator,
                _deployerKey
            );

            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscription(
                _vrfCoordinator,
                _subscriptionID,
                _linkToken,
                _deployerKey
            );
        }

        console.log("Subscription ID: ", _subscriptionID);

        vm.startBroadcast();
        Raffle newRaffle = new Raffle(
            _entryFee,
            _raffleInterval,
            _vrfCoordinator,
            _gasLane,
            _subscriptionID,
            _callbackGasLimit
        );
        vm.stopBroadcast();
        AddConsumer addConsumer = new AddConsumer();
        addConsumer.addConsumer(
            address(newRaffle),
            _vrfCoordinator,
            _subscriptionID,
            _deployerKey
        );
        return (newRaffle, helperConfig);
    }
}
