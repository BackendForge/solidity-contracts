pragma solidity ^0.8.0;

import "./InstantForwarder.sol";

contract InstantForwarderFactory {
    InstantForwarder[] private _deployedForwarders;
    address payable private _ethReceiver;
    address private _erc20Receiver;
    address private _owner;

    event ForwarderCreated(address forwarderAddress, address owner);

    modifier onlyOwner() {
        require(msg.sender == _owner, "FUCK YOU");
        _;
    }

    constructor(address payable ethReceiver_, address erc20Receiver_) {
        _ethReceiver = ethReceiver_;
        require(_ethReceiver != address(0), "-???");
        _erc20Receiver = erc20Receiver_;
        require(_erc20Receiver != address(0), "????");
        _owner = msg.sender;
    }

    function createInstantForwarder() external onlyOwner returns (address) {
        InstantForwarder newForwarder = new InstantForwarder(_ethReceiver, _erc20Receiver, _owner);
        _deployedForwarders.push(newForwarder);
        emit ForwarderCreated(address(newForwarder), msg.sender);
        return address(newForwarder);
    }

    function setReceiver(address payable newReceiver) external onlyOwner {
        require(newReceiver != address(0), "????");
        _ethReceiver = newReceiver;
    }

    function setReceiver20(address payable newReceiver20) external onlyOwner {
        require(newReceiver20 != address(0), "????");
        _erc20Receiver = newReceiver20;
    }

    function changeOwner(address newOwner) external onlyOwner {
        require(newOwner != address(0), "????");
        _owner = newOwner;
    }

    function getDeployedForwarders() external view onlyOwner returns (InstantForwarder[] memory) {
        return _deployedForwarders;
    }
}
