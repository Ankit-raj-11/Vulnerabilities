// SPDX-License-Identifier: MIT
pragma solidity ^0.8.36;

contract Treasury {
    address public owner;
    address public treasury;

    uint256 public fee = 1 ether;
    bool public paused;

    constructor() {
        owner = msg.sender;
        treasury = msg.sender;
    }

    function deposit() external payable {}

   
    function setFee(uint256 newFee) external {
        fee = newFee;
    }

   
    function setTreasury(address newTreasury) external {
        treasury = newTreasury;
    }

   
    function pause() external {
        paused = true;
    }

   
    function withdrawFees() external {
        payable(treasury).transfer(address(this).balance);
    }
}