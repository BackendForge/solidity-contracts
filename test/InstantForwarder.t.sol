// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/InstantForwarder.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

contract ForwarderTest is Test {
    InstantForwarder forwarder;
    MockERC20 token;

    address payable ethReceiver = payable(address(0x1));
    address erc20Receiver = address(0x2);
    address deployer = address(this);
    address attacker = address(0x3);
    uint256 public initialReceiverBalance;

    event EthForwarded(address indexed sender, uint256 amount);

    function setUp() public {
        forwarder = new InstantForwarder(ethReceiver, erc20Receiver, deployer);
        initialReceiverBalance = ethReceiver.balance;
        token = new MockERC20("Test Token", "TTK", 18);
    }

    function testReceiveEth_OnlyOwnerCanForward() public {
        // Send ETH from the owner
        vm.deal(deployer, 1 ether);
        vm.prank(deployer);
        (bool success, ) = address(forwarder).call{value: 0.5 ether}("");
        assertTrue(success);
        assertEq(ethReceiver.balance, 0.5 ether);

        // Attacker should not be able to send ETH
        vm.deal(attacker, 1 ether);
        vm.prank(attacker);
        (success, ) = address(forwarder).call{value: 0.5 ether}("");
        assertFalse(success);
    }

    function testReceiveERC20_TokensAreForwarded() public {
        uint256 amount = 1000 * 10 ** 18;
        token.mint(address(forwarder), amount);

        // Call handleIncomingTokens()
        vm.prank(deployer);
        forwarder.retrieveTokens(address(token), amount);

        // Ensure tokens are forwarded
        assertEq(token.balanceOf(erc20Receiver), amount);
        assertEq(token.balanceOf(address(forwarder)), 0);
    }

    function testforwardETHmotherLodeSuccess() public {
        uint256 amount = 1 ether;
        // Expect EthForwarded event to be emitted.
        vm.expectEmit(true, false, false, true);
        emit EthForwarded(deployer, amount);
        
        // Call forwardETHmotherLode as owner (admin) with 1 ether.
        forwarder.forwardETHmotherLode{value: amount}();

        // Check that ethReceiver balance increased by the amount.
        assertEq(ethReceiver.balance, initialReceiverBalance + amount);
    }

    function testforwardETHmotherLodeFailsNoETH() public {
        vm.expectRevert("-?-?-");
        forwarder.forwardETHmotherLode();
    }

    function testforwardETHmotherLodeFailsNonAdmin() public {
        uint256 amount = 1 ether;
        address nonAdmin = address(0xBEEF);
        vm.deal(nonAdmin, 10 ether);
        vm.prank(nonAdmin);
        vm.expectRevert("FUCK YOU");
        forwarder.forwardETHmotherLode{value: amount}();
    }
}
