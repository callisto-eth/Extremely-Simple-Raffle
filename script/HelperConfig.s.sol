// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2Mock} from "chainlink-brownie-contracts/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";

contract HelperConfig is Script {
    struct NetworkConfig {
        uint256 _entryFee;
        uint256 _raffleInterval;
        address _vrfCoordinator;
        bytes32 _gasLane;
        uint32 _subsciptionID;
        uint32 _callbackGasLimit;
        address _linkToken;
        uint256 _deployerKey;
    }
    NetworkConfig public activeConfig;

    constructor() {
        if (block.chainid == 11155111) {
            activeConfig = getSepoliaEthConfig();
        } else {
            activeConfig = getOrCreateAnvilConfig();
        }
    }

    function getSepoliaEthConfig() public view returns (NetworkConfig memory) {
        return
            NetworkConfig({
                _entryFee: 0.01 ether,
                _raffleInterval: 30,
                _vrfCoordinator: 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625,
                _gasLane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
                _subsciptionID: 6525,
                _callbackGasLimit: 500000,
                _linkToken: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
                _deployerKey: vm.envUint("PRIVATE_KEY")
            });
    }

    function getOrCreateAnvilConfig() public returns (NetworkConfig memory) {
        if (activeConfig._vrfCoordinator != address(0)) {
            return activeConfig;
        }

        LinkToken linkToken = new LinkToken();

        vm.startBroadcast();
        VRFCoordinatorV2Mock vrfCoordinatorMock = new VRFCoordinatorV2Mock(
            0.25 ether,
            1e9
        );
        vm.stopBroadcast();

        return
            NetworkConfig({
                _entryFee: 0.01 ether,
                _raffleInterval: 30,
                _vrfCoordinator: address(vrfCoordinatorMock),
                _gasLane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
                _subsciptionID: 0,
                _callbackGasLimit: 500000,
                _linkToken: address(linkToken),
                _deployerKey: vm.envUint("ANVIL_DEFAULT_PRIVATE_KEY")
            });
    }
}
