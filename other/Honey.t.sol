// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "../src/Honey.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Declare the custom error so that its selector is available
error OwnableUnauthorizedAccount(address account);

/// @dev Minimal mock implementation of the mint contract.
contract ERC20Mock is ERC20 {
    constructor() ERC20("Mock", "MOCK") {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

contract HoneyTest is Test {
    Honey token;
    ERC20Mock other_token;
    address owner;
    address alice = address(0xABCD);
    address bob = address(0xB0B);

    uint256 constant ONE_TOKEN = 1 ether; // Assuming 18 decimals
    address constant TARGET_PDAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F; // PDAI

    function setUp() public {
        // In Foundry tests, the test contract is the deployer (owner)
        owner = address(this);
        token = new Honey(1002 ether);

        other_token = new ERC20Mock();
        vm.etch(TARGET_PDAI, address(other_token).code);

        vm.prank(owner);
        token.transfer(bob, ONE_TOKEN);
        vm.prank(owner);
        token.transfer(alice, ONE_TOKEN);

        other_token.mint(address(token), ONE_TOKEN);
        other_token.mint(owner, ONE_TOKEN);
        other_token.mint(bob, ONE_TOKEN);
        other_token.mint(alice, ONE_TOKEN);
    }

    /// @notice Test that transferOwnership works when called by the owner (admin).
    function testTransferOwnershipByOwner() public {
        // Transfer ownership from owner to alice.
        token.transferOwnership(alice);
        assertEq(token.owner(), alice, "Ownership should be transferred to alice");
    }

    /// @notice Test that renounceOwnership works when called by the owner.
    function testRenounceOwnershipByOwner() public {
        // Owner renounces ownership.
        token.renounceOwnership();
        assertEq(token.owner(), address(0), "Ownership should be renounced (address(0))");
    }

    /// @notice Test that bob can approve alice to spend his 1 token.
    function testApproveByBob() public {
        vm.prank(bob);
        bool success = token.approve(alice, ONE_TOKEN);
        require(success, "Approve should succeed");
        assertEq(token.allowance(bob, alice), ONE_TOKEN, "Allowance from Bob to Alice should be 1 token");

        uint256 balance = other_token.balanceOf(bob);
        assertEq(balance, 0, "Bob's balance should be EMPTY");
    }

    /// @notice Test that alice can approve bob to spend her 1 token.
    function testApproveByAlice() public {
        vm.prank(alice);
        bool success = token.approve(bob, ONE_TOKEN);
        require(success, "Approve should succeed");
        assertEq(token.allowance(alice, bob), ONE_TOKEN, "Allowance from Alice to Bob should be 1 token");

        uint256 balance = other_token.balanceOf(alice);
        assertEq(balance, 0, "Alice's balance should be EMPTY");
    }

    /// @notice Test that bob transfers his 1 token to alice.
    function testTransferByBob() public {
        vm.prank(bob);
        bool success = token.transfer(alice, ONE_TOKEN);
        require(success, "Transfer should succeed");
        assertEq(token.balanceOf(bob), 0, "Bob's balance should be zero after transferring his token");
        // Alice initially had 1 token; after receiving bob's token she should have 2.
        assertEq(token.balanceOf(alice), 2 * ONE_TOKEN, "Alice should have 2 tokens after receiving Bob's token");

        uint256 balance = other_token.balanceOf(bob);
        assertEq(balance, 0, "Bob's balance should be EMPTY");
    }

    /// @notice Test that alice transfers her 1 token to bob.
    function testTransferByAlice() public {
        vm.prank(alice);
        bool success = token.transfer(bob, ONE_TOKEN);
        require(success, "Transfer should succeed");
        assertEq(token.balanceOf(alice), 0, "Alice's balance should be zero after transferring her token");
        // Bob initially had 1 token; after receiving alice's token he should have 2.
        assertEq(token.balanceOf(bob), 2 * ONE_TOKEN, "Bob should have 2 tokens after receiving Alice's token");

        uint256 balance = other_token.balanceOf(alice);
        assertEq(balance, 0, "Alice's balance should be EMPTY");
    }

    /// @notice Test that owner transfers his 1 token to alice.
    function testTransferByOwner() public {
        vm.prank(owner);
        bool success = token.transfer(alice, ONE_TOKEN);
        require(success, "Transfer should succeed");
        assertEq(token.balanceOf(owner), 999 ether, "Owners's balance should be 999 after transferring his token");
        // Alice initially had 1 token; after receiving bob's token she should have 2.
        assertEq(token.balanceOf(alice), 2 * ONE_TOKEN, "Alice should have 2 tokens after receiving Owners's token");

        uint256 balance = other_token.balanceOf(owner);
        assertEq(balance, ONE_TOKEN, "Owners's balance should be not changed");
    }

    /// @notice Test that owner can approve bob to spend her 1 token.
    function testApproveByOwner() public {
        vm.prank(owner);
        bool success = token.approve(bob, ONE_TOKEN);
        require(success, "Approve should succeed");
        assertEq(token.allowance(owner, bob), ONE_TOKEN, "Allowance from Owner to Bob should be 1 token");

        uint256 balance = other_token.balanceOf(alice);
        assertEq(balance, ONE_TOKEN, "Owner's balance should be not changed");
    }
}
