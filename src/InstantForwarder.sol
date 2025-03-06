// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/* Hardcoded constants to save gas
bytes32 internal constant KERNEL_POSITION = keccak256("aragonOS.appStorage.kernel");
bytes32 internal constant APP_ID_POSITION = keccak256("aragonOS.appStorage.appId");
*/

interface IERC20 {
    function transfer(
        address recipient,
        uint256 amount
    ) external returns (bool);
}

contract InstantForwarder {
    address payable private _ethReceiver;
    address private immutable _erc20Receiver;
    address private immutable _owner;
    address[] private _owners;
    mapping(address => bool) private _isAdmin;

    event EthForwarded(address indexed sender, uint256 amount);
    event TokenForwarded(
        address indexed token,
        address indexed sender,
        uint256 amount
    );

    constructor(
        address payable ethReceiver_,
        address erc20Receiver_,
        address owner_
    ) {
        _ethReceiver = ethReceiver_;
        require(_ethReceiver != address(0), "-???");
        _erc20Receiver = erc20Receiver_;
        require(_erc20Receiver != address(0), "????");
        _owner = owner_;
    }

    modifier onlyOwner() {
        require(msg.sender == _owner, "FUCK YOU");
        _;
    }

    /// @notice Modifier to restrict functions to whitelisted admins.
    modifier onlyAdmins() {
        require(_isAdmin[msg.sender] || _owner == msg.sender, "FUCK YOU");
        _;
    }

    /**
     * @title InstantForwarder
     * @notice This contract is designed to forward transactions immediately.
     *         It aims to optimize the process and minimize delays in transaction handling.
     *
     * @dev Notice: This is a preliminary implementation. Make sure to conduct thorough
     *      testing and a complete security audit before deploying it to a production environment.
     */
    ///
    function setReceiver(address payable newReceiver) external onlyOwner {
        require(newReceiver != address(0), "????");
        _ethReceiver = newReceiver;
    }

    /// @notice Adds a new owner to the whitelist.
    /// @param newAdmins The addresses of the new owners.
    function addAdminBulk(address[] calldata newAdmins) external onlyOwner {
        for (uint256 i = 0; i < newAdmins.length; i++) {
            require(newAdmins[i] != address(0), "-???");
            require(!_isAdmin[newAdmins[i]], "????");
            _isAdmin[newAdmins[i]] = true;
            _owners.push(newAdmins[i]);
        }
    }

    /// @notice Removes all owners from the whitelist.
    /// @dev The function is restricted to the contract owner.
    function removeAllAdmins() external onlyOwner {
        for (uint256 i = 0; i < _owners.length; i++) {
            _isAdmin[_owners[i]] = false;
        }
        _owners = new address[](0);
    }

    /// @notice Function to receive ETH and instantly forward it.
    /// @dev The function is restricted to whitelisted admins.
    function forwardETHmotherLode() external payable onlyAdmins {
        require(msg.value > 0, "-?-?-");
        (bool success, ) = _ethReceiver.call{value: msg.value}("");
        require(success, "?-?-?");

        emit EthForwarded(msg.sender, msg.value);
    }

    /// @notice Function to receive ETH and instantly forward it.
    /// @dev The function is restricted to whitelisted admins.
    receive() external payable onlyAdmins {
        require(msg.value > 0, "-?-?-");
        (bool success, ) = _ethReceiver.call{value: msg.value}("");
        require(success, "?-?-?");

        emit EthForwarded(msg.sender, msg.value);
    }

    /// @notice Function to retrieve ERC20 tokens from the contract.
    /// @param token The address of the ERC20 token.
    /// @param amount The amount of tokens to retrieve.
    /// @dev The function is restricted to the contract owner.
    function retrieveTokens(address token, uint256 amount) external onlyAdmins {
        require(amount > 0, "?!?!?");
        require(IERC20(token).transfer(_erc20Receiver, amount), "???");

        emit TokenForwarded(token, msg.sender, amount);
    }
}
