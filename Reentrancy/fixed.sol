// SPDX-License-Identifier: MIT
pragma solidity ^0.8.36;

contract bank{
    mapping(address => uint256) public balance;

    function deposite() external payable {
        balance[msg.sender] += msg.value;
    }

    function withdraw() external {
        uint256 amount = balance[msg.sender];
        require(amount >0, "No funds");
        balance[msg.sender] = 0;
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "failed");
    }

}