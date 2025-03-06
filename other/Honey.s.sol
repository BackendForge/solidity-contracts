// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/Honey.sol"; // adjust the path if needed

// forge script script/Honey.s.sol:DeployHoney --broadcast --rpc-url http://localhost:8555

// needs etherscan key for chain / logic verification
// forge script script/Honey.s.sol:DeployHoney --broadcast --verify --rpc-url <your_rpc_url>

contract DeployHoney is Script {
    function run() external {
        // Load deployer private key from environment variables.
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        uint256 initialSupply = vm.envUint("INITIAL_SUPPLY");

        // Option 2: Hardcode the multicall router address.
        // address multicallRouter = 0xYourMulticallRouterAddress;

        // Start broadcasting transactions.
        vm.startBroadcast(deployerPrivateKey);

        // Deploy the Honey contract.
        Honey honey = new Honey(initialSupply);
        console.log("Honey deployed at:", address(honey));

        // Stop broadcasting transactions.
        vm.stopBroadcast();
    }
}
