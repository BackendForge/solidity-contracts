// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// ---- PoC Python code:
// TODO: auto gas limit (estimate gas)
// class ASYNC, many wallets
// sell extra to PLS?
// check T-PLS liquidity -> min 10$ PLS to enable "Exit" via this "T"
//

// TODO: scope to avoid stack too deep errors
// {
// }
// TODO: error XXXXX(xxxx) -> revert XXXXX(xxxx)
// TODO: addBulkMintBurnMap
// TODO: removeBulkMintBurnMap
// TODO: addBulkAdmins
// TODO: removeBulkAdmins
// TODO: noFlashSwapWithMint
// TODO: noFlashSwapNoMint

//  - we take Y1, Y2, ...
//  ---- THE LOOP
//  - we perform multicall for each Y into X1, X2, ... (DO NOT NEED TO BE THE SAME ENDING TOKEN)
//      - Y1->X1, Y1->X2, Y2->X1, where X1 is X2 parent, where Y1 is X2 parent, where Y2 is Y1 parent etc.
//      - when A->B->C->D, we can go from D up to A, and then from A to D via multiMint
//  - from each multicall, we perform "mint/multiMint" operation, to get into (Z1, Z2, ... |OR| Y1, Y2, ...)
//  ---- END LOOP
//  - we perform "repay" operation (repay all Y1, Y2, ...)
//  - optional: we perform "multicall" from Y1, Y2, ... to get into "A"
//  - we perform "transfer" operation (transfer all A to recipient / transfer all extra Y1, Y2, ... to owner)

/// @notice Minimal interface for Uniswap V2 Pair (flash swap pool)
interface IUniswapV2Pair {
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;

    function token0() external view returns (address);

    function token1() external view returns (address);
}

/// @notice Minimal ERC20 interface
// interface IERC20 {
//     function balanceOf(address account) external view returns (uint256);

//     function transfer(
//         address recipient,
//         uint256 amount
//     ) external returns (bool);

//     function approve(address spender, uint256 amount) external returns (bool);
// }

/// @notice Interface for the multicall-enabled router contract
interface IMulticallRouter {
    function multicall(bytes[] calldata data) external returns (bytes[] memory results);
}

/// @notice Interface for the parent contract
interface IParent {
    function Parent() external view returns (uint256);
}

/// @notice Interface for the mint contract
interface IMint {
    /// @notice Mint function which accepts a token amount
    function mint(uint256 amount) external;
}

// @notice ReentrancyGuard prevents reentrant calls to the contract.
// @dev Use this modifier on functions that should not be reentrant.
contract ReentrancyGuard {
    // Constants representing the status.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    // Variable to track the reentrancy status.
    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    // nonReentrant modifier that prevents reentrant calls.
    modifier nonReentrant() {
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
}

/// @title FlashSwapArb
/// @notice Combines a Uniswap V2 flash swap, a multicall sequence, a mint operation, and repayment.
contract FlashSwapArb is ReentrancyGuard {
    using SafeERC20 for IERC20;

    address public owner;
    address private _multicallRouterAddress;

    IMulticallRouter public multicallRouter;
    bytes32 constant PULSEX_V1_PAIR_CODE_HASH = 0x2b04db39bbbe4838f8dbb7b621b8d49a30d97ac772f095a87ec401ff878d4b10;
    bytes32 constant PULSEX_V2_PAIR_CODE_HASH = 0x4d65271e337c3dbadc69a005b2aa77df8eb7025ab1b5ab3dddb13585b87f4aa5;
    bytes32 constant UNISWAP_V2_PAIR_CODE_HASH = 0x5b83bdbcc56b2e630f2807bbadd2b0c21619108066b92a58de081261089e9ce5;
    mapping(address => bool) public isAdmin;
    mapping(address => address) private _mintBurnMap;
    address[] public owners;

    // struct MintNode {
    //     address mintContract;
    //     MintNode children;
    // }

    /// @notice Emitted when a new owner is added.
    event AdminAdded(address indexed newOwner);

    /// @notice Emitted when an admin is removed.
    event AdminRemoved(address indexed removedOwner);

    /// @notice Emitted when a mint contract is added to the mintBurnMap.
    event MintBurnMapAdded(address indexed mintContract, address indexed burnedToken);

    /// @notice Emitted when a mint contract is removed from the mintBurnMap.
    event MintBurnMapRemoved(address indexed mintContract, address indexed burnedToken);

    /// @notice Modifier to restrict functions to admin.
    modifier onlyOwner() {
        require(owner == msg.sender, "FlashSwapArb: Caller is not owner");
        _;
    }

    /// @notice Modifier to restrict functions to whitelisted admins.
    modifier onlyAdmins() {
        require(isAdmin[msg.sender] || owner == msg.sender, "FlashSwapArb: Caller is not a whitelisted admin");
        _;
    }

    /// @notice Constructor sets the deployer as the owner and initializes the multicall router.
    /// @param _multicallRouter The address of the multicall router contract.
    constructor(address _multicallRouter) {
        require(_multicallRouter != address(0), "Invalid router address");
        _multicallRouterAddress = _multicallRouter;
        multicallRouter = IMulticallRouter(_multicallRouterAddress);
        owner = msg.sender;
        isAdmin[msg.sender] = true;
        owners.push(msg.sender);
        emit AdminAdded(msg.sender);
    }

    function _addMintBurnMap(address mintContract, address burnedToken) internal {
        require(mintContract != address(0), "Invalid mint contract address");
        require(burnedToken != address(0), "Invalid burned token address");
        uint256 currentAllowance = IERC20(burnedToken).allowance(address(this), mintContract);
        if (currentAllowance == 0) {
            require(
                IERC20(burnedToken).approve(mintContract, type(uint256).max),
                "Approval failed - burnedToken to mintContract"
            );
            // IERC20(burnedToken).safeIncreaseAllowance(mintContract, inputBalance);
            // IERC20(burnedToken).approve(mintContract, inputBalance);
        }
        _mintBurnMap[mintContract] = burnedToken;
        emit MintBurnMapAdded(mintContract, burnedToken);
    }

    /// @notice Adds a new mint contract to the mintBurnMap.
    /// @param mintContract The address of the mint contract.
    function addMintBurnMap(address mintContract) external onlyAdmins nonReentrant {
        require(mintContract != address(0), "Invalid mint contract address");
        address burnedToken = address(uint160(uint256(IParent(mintContract).Parent())));
        _addMintBurnMap(mintContract, burnedToken);
    }

    /// @notice Adds a new mint contract to the mintBurnMap.
    /// @param mintContract The address of the mint contract.
    /// @param parentContract The address of the parent contract.
    function addMintBurnMap(address mintContract, address parentContract) external onlyAdmins nonReentrant {
        _addMintBurnMap(mintContract, parentContract);
    }

    /// @notice Adds a new mint contracts to the mintBurnMap.
    /// @param mintContracts The address of the mint contract.
    /// @param burnedTokens The address of the burned token.
    function addMintBurnMapBulk(address[] calldata mintContracts, address[] calldata burnedTokens)
        external
        onlyAdmins
        nonReentrant
    {
        require(mintContracts.length == burnedTokens.length, "Array lengths do not match");
        for (uint256 i = 0; i < mintContracts.length; i++) {
            _addMintBurnMap(mintContracts[i], burnedTokens[i]);
        }
    }

    /// @notice Adds a new mint contracts to the mintBurnMap.
    /// @param mintContracts The address of the mint contract.
    function addMintBurnMapBulk(address[] calldata mintContracts) external onlyAdmins nonReentrant {
        for (uint256 i = 0; i < mintContracts.length; i++) {
            require(mintContracts[i] != address(0), "Invalid mint contract address");
            address burnedToken = address(uint160(uint256(IParent(mintContracts[i]).Parent())));
            _addMintBurnMap(mintContracts[i], burnedToken);
        }
    }

    function _removeMintBurnMap(address mintContract) internal {
        require(_mintBurnMap[mintContract] != address(0), "Invalid mint contract address");
        address burnedToken = _mintBurnMap[mintContract];
        require(IERC20(burnedToken).approve(mintContract, 0), "Approval failed - burnedToken to mintContract");
        _mintBurnMap[mintContract] = address(0);
        emit MintBurnMapRemoved(mintContract, burnedToken);
    }

    /// @notice Removes a mint contract from the mintBurnMap.
    /// @param mintContract The address of the mint contract to remove.
    function removeMintBurnMap(address mintContract) external onlyAdmins nonReentrant {
        _removeMintBurnMap(mintContract);
    }

    /// @notice Removes a mint contracts from the mintBurnMap.
    /// @param mintContracts The address of the mint contract to remove.
    function removeMintBurnMapBulk(address[] calldata mintContracts) external onlyAdmins nonReentrant {
        for (uint256 i = 0; i < mintContracts.length; i++) {
            _removeMintBurnMap(mintContracts[i]);
        }
    }

    /// @notice Allows the contract to mint tokens on behalf of the mint contract.
    /// @param mintContract The address of the mint contract.
    function capAllowance(address mintContract) external onlyAdmins nonReentrant {
        require(_mintBurnMap[mintContract] != address(0), "Invalid mint contract address");
        address burnedToken = _mintBurnMap[mintContract];
        require(
            IERC20(burnedToken).approve(mintContract, type(uint256).max),
            "Approval failed - burnedToken to mintContract"
        );
    }

    /// @notice Allows the contract to mint tokens on behalf of the mint contract.
    /// @param mintContracts The addresses of the mint contracts.
    function capAllowanceBulk(address[] calldata mintContracts) external onlyAdmins nonReentrant {
        for (uint256 i = 0; i < mintContracts.length; i++) {
            require(_mintBurnMap[mintContracts[i]] != address(0), "Invalid mint contract address");
            address burnedToken = _mintBurnMap[mintContracts[i]];
            require(
                IERC20(burnedToken).approve(mintContracts[i], type(uint256).max),
                "Approval failed - burnedToken to mintContract"
            );
        }
    }

    /// @notice Returns the burned token address for a given mint contract.
    /// @param mintContract The address of the mint contract.
    function getMintBurnMap(address mintContract) external view returns (address) {
        address burnedToken = _mintBurnMap[mintContract];
        require(burnedToken != address(0), "Invalid mint contract address");
        return burnedToken;
    }

    /// @notice Returns the burned token address for a given mint contract.
    /// @param mintContracts The addresses of the mint contracts.
    function getMintBurnMapBulk(address[] calldata mintContracts) external view returns (address[] memory) {
        address[] memory burnedTokens = new address[](mintContracts.length);
        for (uint256 i = 0; i < mintContracts.length; i++) {
            address burnedToken = _mintBurnMap[mintContracts[i]];
            require(burnedToken != address(0), "Invalid mint contract address");
            burnedTokens[i] = burnedToken;
        }
        return burnedTokens;
    }

    /// @notice Adds a new owner to the whitelist.
    /// @param newAdmin The address of the new owner.
    function addAdmin(address newAdmin) external onlyOwner {
        require(newAdmin != address(0), "Invalid new owner address");
        require(!isAdmin[newAdmin], "Address is already an admin");
        isAdmin[newAdmin] = true;
        owners.push(newAdmin);
        emit AdminAdded(newAdmin);
    }

    /// @notice Adds a new owner to the whitelist.
    /// @param newAdmins The addresses of the new owners.
    function addAdminBulk(address[] calldata newAdmins) external onlyOwner {
        for (uint256 i = 0; i < newAdmins.length; i++) {
            require(newAdmins[i] != address(0), "Invalid new owner address");
            require(!isAdmin[newAdmins[i]], "Address is already an admin");
            isAdmin[newAdmins[i]] = true;
            owners.push(newAdmins[i]);
            emit AdminAdded(newAdmins[i]);
        }
    }

    /// @notice Removes all owners from the whitelist.
    /// @dev This function is irreversible.
    function removeAllAdmins() external onlyOwner {
        for (uint256 i = 0; i < owners.length; i++) {
            isAdmin[owners[i]] = false;
        }
        owners = new address[](0);
    }

    /// @notice Removes an admin from the whitelist.
    /// @param adminToRemove The address of the owner to remove.
    function removeAdmin(address adminToRemove) external onlyOwner {
        require(isAdmin[adminToRemove], "Address is not an admin");
        require(adminToRemove != msg.sender, "Owners cannot remove themselves");
        isAdmin[adminToRemove] = false;

        // Optionally remove from the array (for enumeration purposes)
        for (uint256 i = 0; i < owners.length; i++) {
            if (owners[i] == adminToRemove) {
                owners[i] = owners[owners.length - 1];
                owners.pop();
                break;
            }
        }
        emit AdminRemoved(adminToRemove);
    }

    /// @notice Get the code hash of a Uniswap V2 pair contract.
    /// @param pool The address of the Uniswap V2 pair contract.
    function getPairCodeHash(address pool) external view returns (bytes32 codeHash) {
        assembly {
            codeHash := extcodehash(pool)
        }
    }

    /// @notice Entry point to execute the full strategy.
    /// @param initialPool The Uniswap V2 pair address to flash swap from.
    /// @param amount0Out The amount of token0 to borrow (set one of these to nonzero).
    /// @param amount1Out The amount of token1 to borrow.
    /// @param multicallData An array of fully encoded calls for the multicall sequence.
    /// @param flashSwapToken The token address to approve for the flash swap.
    /// @param mintContracts The addresses of the contracts that will mint tokens.
    /// @param recipient The address to receive any extra output tokens.
    function flashSwapWithMint(
        address initialPool,
        uint256 amount0Out,
        uint256 amount1Out,
        bytes[] calldata multicallData,
        address flashSwapToken,
        address[] calldata mintContracts,
        address recipient
    ) external onlyAdmins {
        // Encode the additional parameters to pass to the flash swap callback.
        // In flashSwapWithMint, you could encode the pool address along with other parameters:
        for (uint256 i = 0; i < mintContracts.length; i++) {
            require(_mintBurnMap[mintContracts[i]] != address(0), "Mint contract not found in mintBurnMap");
        }
        bytes memory data = abi.encode(initialPool, multicallData, mintContracts, recipient);

        require(
            IERC20(flashSwapToken).approve(_multicallRouterAddress, type(uint256).max),
            "Approval failed - flashSwapToken to multicallRouter"
        );

        // Initiate flash swap from the given pool.
        IUniswapV2Pair(initialPool).swap(amount0Out, amount1Out, address(this), data);

        // After the flash swap completes, any extra tokens can be kept in this contract
        // or withdrawn later via a separate function.
    }

    /// @notice Entry point to execute the full strategy.
    /// @param initialPool The Uniswap V2 pair address to flash swap from.
    /// @param amount0Out The amount of token0 to borrow (set one of these to nonzero).
    /// @param amount1Out The amount of token1 to borrow.
    /// @param multicallData An array of fully encoded calls for the multicall sequence.
    /// @param flashSwapToken The token address to approve for the flash swap.
    /// @param recipient The address to receive any extra output tokens.
    function flashSwapNoMint(
        address initialPool,
        uint256 amount0Out,
        uint256 amount1Out,
        bytes[] calldata multicallData,
        address flashSwapToken,
        address recipient
    ) external onlyAdmins {
        // Encode the additional parameters to pass to the flash swap callback.
        // In flashSwapWithMint, you could encode the pool address along with other parameters:
        address[] memory dummyContracts = new address[](0);
        bytes memory data = abi.encode(initialPool, multicallData, dummyContracts, recipient);

        require(
            IERC20(flashSwapToken).approve(_multicallRouterAddress, type(uint256).max),
            "Approval failed - flashSwapToken to multicallRouter"
        );

        // Initiate flash swap from the given pool.
        IUniswapV2Pair(initialPool).swap(amount0Out, amount1Out, address(this), data);

        // After the flash swap completes, any extra tokens can be kept in this contract
        // or withdrawn later via a separate function.
    }

    /// @notice Uniswap V2 flash swap callback.
    /// @dev Called by the pool after initiating the flash swap.
    /// @param sender The initiator of the swap (should be this contract).
    /// @param amount0 The amount of token0 borrowed.
    /// @param amount1 The amount of token1 borrowed.
    /// @param data Encoded parameters passed from flashSwapWithMint.
    function uniswapV2Call(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external {
        // Decode the pool address and other parameters from the callback data
        (address expectedPool, bytes[] memory multicallData, address[] memory mintContracts, address recipient) =
            abi.decode(data, (address, bytes[], address[], address));

        // Verify that msg.sender (the caller) is the expected pool address.
        require(msg.sender == expectedPool, "Caller is not the expected pair");

        // bytes32 callerCodeHash;
        // assembly {
        //     callerCodeHash := extcodehash(caller())
        // }
        // require(
        //     callerCodeHash == PULSEX_V1_PAIR_CODE_HASH ||
        //         callerCodeHash == PULSEX_V2_PAIR_CODE_HASH,
        //     "Caller is not a valid pair"
        // );

        // --- 1. Execute the multicall sequence ---
        // This sequence should perform a series of swaps that ultimately result in a balance
        // of `burnedToken` available in this contract.

        multicallRouter.multicall(multicallData);

        // --- 2. Mint tokens to obtain the required asset for repayment ---
        // We assume that the mint contract will "burn" the available burnedToken in exchange for minting
        // the asset needed to repay the flash swap.
        for (uint256 i = 0; i < mintContracts.length; i++) {
            address burnedToken = _mintBurnMap[mintContracts[i]];
            if (burnedToken != address(0)) {
                uint256 inputBalance = IERC20(burnedToken).balanceOf(address(this));
                require(inputBalance > 0, "No input tokens from multicall to burn");

                // Call mint; assume the minted tokens are sent directly to this contract.
                IMint(mintContracts[i]).mint(inputBalance);
                uint256 mintedAmount = IERC20(mintContracts[i]).balanceOf(address(this));
                require(mintedAmount > 0, "Mint failed");
            }
        }

        // --- 3. Repay the flash swap ---
        // Determine which token was borrowed and calculate the amount to repay.
        uint256 repayment;
        address repayToken;
        if (amount0 > 0) {
            // Token0 was borrowed.
            repayment = (amount1 * 1000 + 996) / 997;
            repayToken = IUniswapV2Pair(msg.sender).token0();
        } else {
            // Token1 was borrowed.
            // repayment = ((amount1 * 1000) / 997) + 1;
            repayment = (amount1 * 1000 + 996) / 997;
            repayToken = IUniswapV2Pair(msg.sender).token1();
        }

        // --- 4. Verify minted token balance ---
        // Ensure that the minted tokens (assumed to be the same as the repay token)
        // are sufficient to cover the repayment.
        uint256 mintedTokenBalance = IERC20(repayToken).balanceOf(address(this));
        require(mintedTokenBalance > repayment, "Insufficient minted tokens for repayment & extra");

        // --- 5. Repay the flash swap ---
        // Transfer the required repayment amount back to the pool.
        require(IERC20(repayToken).transfer(msg.sender, repayment), "Repayment transfer failed");

        // --- 6. Transfer any extra minted tokens to the recipient ---
        // For simplicity, we assume that the minted token is the same as repayToken.
        // If it is a different token, adjust accordingly.
        uint256 extra = IERC20(repayToken).balanceOf(address(this));
        if (extra > 0) {
            require(IERC20(repayToken).transfer(recipient, extra), "Extra transfer failed");
        }
    }

    /// @notice Withdraws any ERC20 tokens held by the contract.
    /// @param token The address of the token to withdraw.
    /// @param recipient The address to receive the withdrawn tokens.
    function withdrawToken(address token, address recipient) external onlyOwner {
        uint256 balance = IERC20(token).balanceOf(address(this));
        require(balance > 0, "No tokens to withdraw");
        require(IERC20(token).transfer(recipient, balance), "Token transfer failed");
    }

    /// @notice Withdraws any ETH held by the contract.
    /// @param recipient The address to receive the withdrawn ETH.
    function withdrawETH(address recipient) external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No ETH to withdraw");
        (bool sent,) = recipient.call{value: balance}("");
        require(sent, "?-?-?");
    }

    // fallback() external payable {
    //     // Logic to handle unknown calls or Ether sent with data.
    //     (bool sent, ) = owner.call{value: msg.value}("");
    //     require(sent, "Transfer to owner failed");
    // }

    // receive() external payable {
    //     // Logic to handle the Ether received.
    //     (bool sent, ) = owner.call{value: msg.value}("");
    //     require(sent, "Transfer to owner failed");
    // }
}
