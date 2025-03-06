// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/FlashSwapArb.sol";

/// @dev Minimal mock implementation of the multicall router.
contract MulticallRouterMock is IMulticallRouter {
    // For simplicity, just return an empty array with the same length as input.
    function multicall(bytes[] calldata data) external pure override returns (bytes[] memory results) {
        results = new bytes[](data.length);
    }
}

/// @dev Minimal mock implementation of the mint contract.
contract MintMock is IMint {
    address private _token;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;

    constructor(address tokenAddress) {
        require(tokenAddress != address(0), "Token address cannot be zero");
        _token = tokenAddress;
        totalSupply = 1000 ether;
        balanceOf[msg.sender] = 1000 ether;
    }

    /// @dev Mint tokens to the caller.
    /// @param amount The amount of tokens to mint. Ratio is 1:1 with the token.
    function mint(uint256 amount) external override {
        IERC20(_token).transferFrom(msg.sender, address(this), amount);
        balanceOf[msg.sender] += amount;
        totalSupply += amount;
    }

    // Zwracamy adres tokena jako uint256 (tak jak wymagane w interfejsie)
    function Parent() external view returns (uint256) {
        return uint256(uint160(_token));
    }
}

/// @dev Minimal mock implementation of a Uniswap V2 Pair.
/// When swap() is called, it immediately triggers the flash swap callback.
contract UniswapV2PairMock is IUniswapV2Pair {
    address public override token0;
    address public override token1;

    // Set token0 and token1 in constructor.
    constructor(address _token0, address _token1) {
        token0 = _token0;
        token1 = _token1;
    }

    /// @dev Simulate a flash swap by calling uniswapV2Call on the `to` address.
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external override {
        if (amount0Out > 0) {
            ITestERC20(token0).mint(to, amount0Out);
        }
        if (amount1Out > 0) {
            ITestERC20(token1).mint(to, amount1Out);
        }

        FlashSwapArb(to).uniswapV2Call(address(this), amount0Out, amount1Out, data);
    }
}

interface ITestERC20 is IERC20 {
    function mint(address account, uint256 amount) external;
}

/// @dev Minimal ERC20 implementation for testing.
contract TestERC20 is ITestERC20 {
    string public name = "TestERC20";
    string public symbol = "TST";
    uint8 public decimals = 18;
    uint256 public override totalSupply;

    mapping(address => uint256) public override balanceOf;
    mapping(address => mapping(address => uint256)) public override allowance;

    constructor(uint256 _initialSupply) {
        totalSupply = _initialSupply;
        balanceOf[msg.sender] = _initialSupply;
    }

    function transfer(address recipient, uint256 amount) external override returns (bool) {
        require(balanceOf[msg.sender] >= amount, "Not enough tokens");
        balanceOf[msg.sender] -= amount;
        balanceOf[recipient] += amount;
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) external override returns (bool) {
        require(balanceOf[sender] >= amount, "Not enough tokens");
        require(allowance[sender][msg.sender] >= amount, "Not enough allowance");
        balanceOf[sender] -= amount;
        balanceOf[recipient] += amount;
        allowance[sender][msg.sender] -= amount;
        return true;
    }

    function approve(address spender, uint256 amount) external override returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function mint(address account, uint256 amount) external {
        balanceOf[account] += amount;
        totalSupply += amount;
    }
}

/// @dev Test contract for FlashSwapArb.
contract FlashSwapArbTest is Test {
    FlashSwapArb arb;
    MulticallRouterMock multicallRouter;
    MintMock mint;
    MintMock mint2;
    TestERC20 tokenA;
    TestERC20 tokenB;
    UniswapV2PairMock pair;

    // Test addresses for owner and tokens.
    address initialOwner = address(0xBEEF);
    address newOwner = address(0x1234);
    address nonOwner = address(0xCAFE);
    address recipient = address(0xDEAD);

    // Event definitions (must match those in the contract)
    event AdminAdded(address indexed newOwner);
    event AdminRemoved(address indexed removedOwner);

    /// @dev setUp deploys the mocks and the FlashSwapArb contract.
    function setUp() public {
        // Deploy the multicall router mock.
        multicallRouter = new MulticallRouterMock();

        // Use vm.prank to deploy as the owner.
        vm.prank(initialOwner);
        arb = new FlashSwapArb(address(multicallRouter));

        // Deploy two test tokens for the Uniswap V2 Pair mock.
        tokenA = new TestERC20(100000000 ether);
        tokenB = new TestERC20(100000000 ether);

        // Deploy the mint mock.
        mint = new MintMock(address(tokenA));
        mint2 = new MintMock(address(tokenB));

        // Deploy the Uniswap V2 Pair mock with tokenA as token0 and tokenB as token1.
        pair = new UniswapV2PairMock(address(tokenA), address(tokenB));

        // tokenA.transfer(address(arb), 10000 ether);
        // tokenB.transfer(address(arb), 10000 ether);
    }

    /// @dev Tests that the initial owner is correctly set.
    function testOwner() public view {
        // Check that the deployer (initialOwner) is whitelisted.
        bool isOwnerFlag = arb.isAdmin(initialOwner);
        assertTrue(isOwnerFlag, "Initial owner must be whitelisted");

        // Check that the owners array contains the initialOwner at index 0.
        address ownerFromArray = arb.owners(0);
        assertEq(ownerFromArray, initialOwner, "First owner in array should be the initial owner");
    }

    function testAddAdmin() public {
        // Verify that newOwner is not already whitelisted.
        bool isOwnerBefore = arb.isAdmin(newOwner);
        assertEq(isOwnerBefore, false, "newOwner should not be whitelisted initially");

        // Call addOwner from the initial owner.
        vm.prank(initialOwner);
        // Expect the AdminAdded event to be emitted.
        vm.expectEmit(true, false, false, true);
        emit AdminAdded(newOwner);
        arb.addAdmin(newOwner);

        // Verify that newOwner is now whitelisted.
        bool isOwnerAfter = arb.isAdmin(newOwner);
        assertTrue(isOwnerAfter, "newOwner should be whitelisted after addAdmin");
    }

    function testAddAdminBulk() public {
        // Add newOwner and nonOwner in bulk.
        address[] memory newOwners = new address[](2);
        newOwners[0] = newOwner;
        newOwners[1] = nonOwner;

        // Verify that newOwner and nonOwner are not already whitelisted.
        bool isOwnerBefore = arb.isAdmin(newOwner);
        assertEq(isOwnerBefore, false, "newOwner should not be whitelisted initially");
        bool isNonOwnerBefore = arb.isAdmin(nonOwner);
        assertEq(isNonOwnerBefore, false, "nonOwner should not be whitelisted initially");

        // Call addOwner from the initial owner.
        vm.prank(initialOwner);
        // Expect the AdminAdded event to be emitted for both newOwner and nonOwner.
        vm.expectEmit(true, false, false, true);
        emit AdminAdded(newOwner);
        vm.expectEmit(true, false, false, true);
        emit AdminAdded(nonOwner);
        arb.addAdminBulk(newOwners);

        // Verify that newOwner and nonOwner are now whitelisted.
        bool isOwnerAfter = arb.isAdmin(newOwner);
        assertTrue(isOwnerAfter, "newOwner should be whitelisted after addAdmin");
        bool isNonOwnerAfter = arb.isAdmin(nonOwner);
        assertTrue(isNonOwnerAfter, "nonOwner should be whitelisted after addAdmin");
    }

    function testRemoveAdmin() public {
        // First, add newOwner.
        vm.prank(initialOwner);
        arb.addAdmin(newOwner);
        bool isAdminAdded = arb.isAdmin(newOwner);
        assertTrue(isAdminAdded, "newOwner should be whitelisted after being added");

        // Now, remove newOwner using initialOwner (note: owners cannot remove themselves).
        vm.prank(initialOwner);
        vm.expectEmit(true, false, false, true);
        emit AdminRemoved(newOwner);
        arb.removeAdmin(newOwner);

        // Verify that newOwner is no longer whitelisted.
        bool isOwnerAfter = arb.isAdmin(newOwner);
        assertFalse(isOwnerAfter, "newOwner should not be whitelisted after removal");
    }

    /// @dev Tests a simulated flash swap flow.
    /// In this test, we:
    /// 1. Call flashSwapWithMint from the owner.
    /// 2. flashSwapWithMint calls pair.swap.
    /// 3. The pair mock calls uniswapV2Call on our contract.
    /// Note: For simplicity, token transfers are not fully simulated.
    function testFlashSwapWithMint() public {
        // We'll borrow tokenA by setting amount0Out nonzero.
        uint256 amount0Out = 1000000;
        uint256 amount1Out = 0;
        // For multicall data, we pass an empty array.
        bytes[] memory multicallData = new bytes[](0);
        address[] memory mintContracts = new address[](1);
        mintContracts[0] = address(mint);

        // add mint-burn mapping
        vm.prank(initialOwner);
        arb.addMintBurnMap(address(mint));

        // Execute strategy from the owner.
        vm.prank(initialOwner);
        vm.expectRevert("Insufficient minted tokens for repayment & extra");
        arb.flashSwapWithMint(
            address(pair), // initial pool address
            amount0Out, // borrow token0
            amount1Out, // borrow token1
            multicallData, // empty multicall array
            address(tokenA), // flash swap token
            mintContracts, // mint contracts addresses
            recipient // recipient for extra tokens
        );
        // If no revert occurs, we assume that the simulated flash swap flow works.
    }

    /// @dev Tests a simulated flash swap flow with no minting feature.
    /// In this test, we:
    /// 1. Call flashSwapWithMint from the owner.
    /// 2. flashSwapWithMint calls pair.swap.
    /// 3. The pair mock calls uniswapV2Call on our contract.
    /// Note: For simplicity, token transfers are not fully simulated.
    function testFlashSwapWithNoMint() public {
        // We'll borrow tokenA by setting amount0Out nonzero.
        uint256 amount0Out = 1000000;
        uint256 amount1Out = 0;
        // For multicall data, we pass an empty array.
        bytes[] memory multicallData = new bytes[](0);

        // Execute strategy from the owner.
        vm.prank(initialOwner);
        arb.flashSwapNoMint(
            address(pair), // initial pool address
            amount0Out, // borrow token0
            amount1Out, // borrow token1
            multicallData, // empty multicall array
            address(tokenA), // flash swap token
            recipient // recipient for extra tokens
        );
        // If no revert occurs, we assume that the simulated flash swap flow works.
    }

    /// @dev Tests adding a mint–burn mapping.
    function testAddMintBurnMap() public {
        // Deploy a test token to represent the burned token.
        TestERC20 burnedToken = new TestERC20(1000 ether);
        MintMock mintContract = new MintMock(address(burnedToken));
        address burnedAddress = address(burnedToken);
        address mintContractAddress = address(mintContract);

        // Initially, allowance from arb to mintContract should be zero.
        uint256 initialAllowance = burnedToken.allowance(address(arb), mintContractAddress);
        assertEq(initialAllowance, 0);

        // Add the mapping using addMintBurnMap (onlyOwner).
        vm.prank(initialOwner);
        arb.addMintBurnMap(mintContractAddress);

        // Verify that the mapping is set correctly via getMintBurnMap.
        vm.prank(initialOwner);
        address mappedToken = arb.getMintBurnMap(mintContractAddress);
        assertEq(mappedToken, burnedAddress);

        // Verify that the allowance has been set to type(uint256).max.
        uint256 newAllowance = burnedToken.allowance(address(arb), mintContractAddress);
        assertEq(newAllowance, type(uint256).max);
    }

    /// @dev Tests that a non-owner cannot add a mint–burn mapping.
    function testNonOwnerCannotAddMintBurnMap() public {
        TestERC20 burnedToken = new TestERC20(1000 ether);
        MintMock mintContract = new MintMock(address(burnedToken));
        vm.prank(nonOwner);
        vm.expectRevert("FlashSwapArb: Caller is not a whitelisted admin");
        arb.addMintBurnMap(address(mintContract));
    }

    /// @dev Tests retrieving the mint–burn mapping.
    function testGetMintBurnMap() public {
        TestERC20 burnedToken = new TestERC20(1000 ether);
        MintMock mintContract = new MintMock(address(burnedToken));
        vm.prank(initialOwner);
        arb.addMintBurnMap(address(mintContract));

        address returnedToken = arb.getMintBurnMap(address(mintContract));
        assertEq(returnedToken, address(burnedToken));
    }

    /// @dev Tests removing the mint–burn mapping.
    function testRemoveMintBurnMap() public {
        TestERC20 burnedToken = new TestERC20(1000 ether);
        MintMock mintContract = new MintMock(address(burnedToken));

        // First, add the mapping.
        vm.prank(initialOwner);
        arb.addMintBurnMap(address(mintContract));

        // Then, remove the mapping.
        vm.prank(initialOwner);
        arb.removeMintBurnMap(address(mintContract));

        // Verify that the mapping returns zero address.
        vm.expectRevert("Invalid mint contract address");
        arb.getMintBurnMap(address(mintContract)); // address mappedToken

        // Verify that the allowance is reset to 0.
        uint256 allowanceAfter = burnedToken.allowance(address(arb), address(mintContract));
        assertEq(allowanceAfter, 0);
    }

    /// @dev Tests that a non-owner cannot remove the mint–burn mapping.
    function testNonOwnerCannotRemoveMintBurnMap() public {
        vm.prank(nonOwner);
        vm.expectRevert("FlashSwapArb: Caller is not a whitelisted admin");
        arb.removeMintBurnMap(address(0x1111));
    }

    /// @dev Tests that a owner can cap the allowance.
    function testCapAllowance() public {
        // Deploy a test token representing the burned token.
        TestERC20 burnedToken = new TestERC20(1000 ether);
        // address burnedAddress = address(burnedToken);

        // Deploy a MintMock using the burned token.
        MintMock mintContract = new MintMock(address(burnedToken));
        address mintContractAddress = address(mintContract);

        // Initially, allowance from arb to mintContract should be zero.
        uint256 initialAllowance = burnedToken.allowance(address(arb), mintContractAddress);
        assertEq(initialAllowance, 0, "Allowance should be 0 initially");

        // Add the mint-burn mapping (only admin/owner can do that).
        vm.prank(initialOwner);
        arb.addMintBurnMap(mintContractAddress);

        // Now, call capAllowance as admin.
        vm.prank(initialOwner);
        arb.capAllowance(mintContractAddress);

        // Verify that the allowance has been set to type(uint256).max.
        uint256 newAllowance = burnedToken.allowance(address(arb), mintContractAddress);
        assertEq(newAllowance, type(uint256).max, "Allowance should be set to max");
    }

    /// @notice Test bulk addition using addMintBurnMapBulk (overload with mintContracts only).
    function testAddMintBurnMapBulk() public {
        address[] memory mintContracts = new address[](2);
        mintContracts[0] = address(mint);
        mintContracts[1] = address(mint2);

        // Call bulk add (the one that derives burnedToken via IParent)
        vm.prank(initialOwner);
        arb.addMintBurnMapBulk(mintContracts);

        // Retrieve the burned tokens from the mapping.
        address[] memory burnedTokens = arb.getMintBurnMapBulk(mintContracts);
        require(burnedTokens[0] == address(tokenA), "Incorrect burned token for mint1");
        require(burnedTokens[1] == address(tokenB), "Incorrect burned token for mint2");
    }

    /// @notice Test bulk removal using removeMintBurnMapBulk.
    function testRemoveMintBurnMapBulk() public {
        address[] memory mintContracts = new address[](2);
        mintContracts[0] = address(mint);
        mintContracts[1] = address(mint2);

        // First, add the mintBurn maps.
        vm.prank(initialOwner);
        arb.addMintBurnMapBulk(mintContracts);

        // Now, remove them in bulk.
        vm.prank(initialOwner);
        arb.removeMintBurnMapBulk(mintContracts);

        // Verify removal: calling getMintBurnMap should revert.
        bool removed;
        // We use a low-level call to capture the revert for one of the removed keys.
        (removed,) = address(arb).call(abi.encodeWithSignature("getMintBurnMap(address)", mintContracts[0]));
        require(!removed, "MintBurnMap was not removed for mint1");
    }

    /// @notice Test bulk capAllowance using capAllowanceBulk.
    function testCapAllowanceBulk() public {
        address[] memory mintContracts = new address[](2);
        mintContracts[0] = address(mint);
        mintContracts[1] = address(mint2);

        // Add the mintBurn maps.
        vm.prank(initialOwner);
        arb.addMintBurnMapBulk(mintContracts);

        // Call capAllowanceBulk.
        vm.prank(initialOwner);
        arb.capAllowanceBulk(mintContracts);

        // Check that allowances have been set to uint256 maximum.
        uint256 allowance1 = tokenA.allowance(address(arb), address(mint));
        uint256 allowance2 = tokenB.allowance(address(arb), address(mint2));
        require(allowance1 == type(uint256).max, "Allowance not set correctly for token1");
        require(allowance2 == type(uint256).max, "Allowance not set correctly for token2");
    }

    /// @notice Test withdrawToken function.
    function testWithdrawToken() public {
        uint256 depositAmount = 1000 ether;

        // Transfer tokens to the arb contract (simulate tokens held by the contract)
        assertTrue(tokenA.transfer(address(arb), depositAmount), "Token transfer to arb failed");
        uint256 arbTokenBalance = tokenA.balanceOf(address(arb));
        assertEq(arbTokenBalance, depositAmount, "Incorrect arb tokenA balance");

        // Withdraw tokens from arb as the owner
        vm.prank(initialOwner);
        arb.withdrawToken(address(tokenA), recipient);

        // Check that recipient's tokenA balance increased and arb's tokenA balance is zero.
        uint256 recipientTokenBalance = tokenA.balanceOf(recipient);
        assertEq(recipientTokenBalance, depositAmount, "Recipient did not receive tokens");
        arbTokenBalance = tokenA.balanceOf(address(arb));
        assertEq(arbTokenBalance, 0, "Arb contract should have zero tokenA balance");
    }

    // function testWithdrawETH() public {
    //     uint256 depositAmount = 1 ether;

    //     // Send ETH to arb contract
    //     (bool sent, ) = address(arb).call{value: depositAmount}("");
    //     require(sent, "ETH deposit failed");
    //     uint256 arbEthBalance = address(arb).balance;
    //     assertEq(arbEthBalance, depositAmount, "Incorrect ETH balance in arb");

    //     // Record recipient's balance before withdrawal.
    //     uint256 recipientBalanceBefore = recipient.balance;

    //     // Withdraw ETH from arb as owner.
    //     vm.prank(initialOwner);
    //     arb.withdrawETH(recipient);

    //     // Verify arb balance is zero and recipient received the ETH.
    //     arbEthBalance = address(arb).balance;
    //     assertEq(arbEthBalance, 0, "Arb ETH balance should be zero after withdrawal");
    //     uint256 recipientBalanceAfter = recipient.balance;
    //     assertEq(
    //         recipientBalanceAfter,
    //         recipientBalanceBefore + depositAmount,
    //         "Recipient did not receive the correct ETH amount"
    //     );
    // }

    // /// @notice Test the fallback function to forward ether to the owner.
    // function testFallbackForward() public {
    //     // Get the current owner address and its balance.
    //     address ownerAddr = arb.owner();
    //     uint256 ownerBalanceBefore = ownerAddr.balance;

    //     // Amount of ether to send.
    //     uint256 amount = 1 ether;

    //     // Allocate ether to a test sender and simulate a call with non-empty data to trigger the fallback.
    //     address sender = address(0x1234);
    //     vm.deal(sender, amount);
    //     vm.prank(sender);
    //     // Send arbitrary data to ensure fallback is triggered (not the receive function).
    //     (bool success, ) = address(arb).call{value: amount}(hex"abcd");
    //     require(success, "Fallback call failed");

    //     // Verify the owner received the ether.
    //     uint256 ownerBalanceAfter = ownerAddr.balance;
    //     assertEq(
    //         ownerBalanceAfter,
    //         ownerBalanceBefore + amount,
    //         "Owner balance did not increase by sent amount"
    //     );
    // }

    // /// @notice Test the receive function to forward ether to the owner.
    // function testReceiveForward() public {
    //     // Get the current owner address and its balance.
    //     address ownerAddr = arb.owner();
    //     uint256 ownerBalanceBefore = ownerAddr.balance;

    //     // Amount of ether to send.
    //     uint256 amount = 0.5 ether;

    //     // Allocate ether to a test sender and simulate an empty call (no data) to trigger the receive function.
    //     address sender = address(0x5678);
    //     vm.deal(sender, amount);
    //     vm.prank(sender);
    //     (bool success, ) = payable(address(arb)).call{value: amount}(
    //         ""
    //     );
    //     require(success, "Receive call failed");

    //     // Verify the owner received the ether.
    //     uint256 ownerBalanceAfter = ownerAddr.balance;
    //     assertEq(
    //         ownerBalanceAfter,
    //         ownerBalanceBefore + amount,
    //         "Owner balance did not increase by sent amount"
    //     );
    // }
}
