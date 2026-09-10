// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract VulnerableWallet {
    address public owner;

    constructor() payable {
        owner = msg.sender;
    }

    function deposit() external payable {}

    function withdraw(address payable _to, uint256 _amount) external {
        // VULNERABLE: Using tx.origin for authentication allows phishing attacks.
        // If the owner interacts with a malicious contract, that contract can call
        // withdraw() and pass the check because tx.origin is still the owner.
        require(tx.origin == owner, "Not owner");
        require(address(this).balance >= _amount, "Insufficient balance");

        (bool success, ) = _to.call{value: _amount}("");
        require(success, "Transfer failed");
    }

    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
