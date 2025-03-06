// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// import {Script} from "forge-std/Script.sol";
import "forge-std/Script.sol";
import {InstantForwarder} from "../src/InstantForwarder.sol";

// forge script script/InstantForwarder.s.sol:DeployForwarder --broadcast --rpc-url https://rpc-pulsechain.g4mm4.io

contract DeployForwarder is Script {
    function setUp() public {}

    function run() public {
        // Hardcoded receiver addresses (update as needed)
        address payable ethReceiver = payable(vm.envAddress("ETH_RECEIVER"));
        address erc20Receiver = vm.envAddress("RECEIVER");

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);
        // Deploy the contract
        InstantForwarder forwarder = new InstantForwarder(ethReceiver, erc20Receiver, deployer);

        console.log("InstantForwarder deployed at:", address(forwarder));

        vm.stopBroadcast();
    }
}
