// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// import {Script} from "forge-std/Script.sol";
import "forge-std/Script.sol";
import {InstantForwarderFactory} from "../src/ForwarderFactory.sol";

// forge script script/ForwarderFactory.s.sol:DeployForwarderFactory --broadcast --rpc-url https://rpc-pulsechain.g4mm4.io
// forge script script/ForwarderFactory.s.sol:DeployForwarderFactory --broadcast --rpc-url https://rpc.pulsechain.com
contract DeployForwarderFactory is Script {
    function setUp() public {}

    function run() public {
        // Hardcoded receiver addresses (update as needed)
        address payable ethReceiver = payable(vm.envAddress("ETH_RECEIVER"));
        address erc20Receiver = vm.envAddress("RECEIVER");

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        // Deploy the contract
        InstantForwarderFactory forwarder_factory = new InstantForwarderFactory(
            ethReceiver,
            erc20Receiver
        );

        console.log(
            "InstantForwarderFactory deployed at:",
            address(forwarder_factory)
        );

        vm.stopBroadcast();
    }
}
