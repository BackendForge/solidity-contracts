// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/FlashSwapArb.sol"; // adjust the path if needed

// forge script script/FlashSwapArb.s.sol:DeployFlashSwapArb --broadcast --rpc-url http://localhost:8555

// needs etherscan key for chain / logic verification
// forge script script/FlashSwapArb.s.sol:DeployFlashSwapArb --broadcast --verify --rpc-url <your_rpc_url>

contract DeployFlashSwapArb is Script {
    function run() external {
        // Load deployer private key from environment variables.
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Option 1: Get multicall router address from environment variables.
        // Make sure to set the MULTICALL_ROUTER env var before running the script.
        address multicallRouter = vm.envAddress("MULTICALL_ROUTER");

        // Option 2: Hardcode the multicall router address.
        // address multicallRouter = 0xYourMulticallRouterAddress;

        // Start broadcasting transactions.
        vm.startBroadcast(deployerPrivateKey);

        // Deploy the FlashSwapArb contract.
        FlashSwapArb arb = new FlashSwapArb(multicallRouter);
        console.log("FlashSwapArb deployed at:", address(arb));

        // Stop broadcasting transactions.
        vm.stopBroadcast();
    }
}
