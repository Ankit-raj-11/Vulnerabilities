// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Treasury {
    address public owner;
    address public treasury;

    uint256 public fee = 1 ether;
    bool public paused;

    constructor() {
        owner = msg.sender;
        treasury = msg.sender;
    }

    function deposit() external payable {
        require(paused = true, "sorry");
    }

   
    function setFee(uint256 newFee) external {
        require(msg.sender == owner, "you are not autorized");
        fee = newFee;
    }

   
    function setTreasury(address newTreasury) external {
        require(msg.sender == owner, "you are not autorized");
        treasury = newTreasury;
    }

   function pause() external {
    require(
        msg.sender == owner || msg.sender == treasury,
        "you are not authorized"
    );

    paused = true;
}
   
    function withdrawFees() external {
        (bool success, ) = payable(treasury).call{value: address(this).balance}("");
        require(success, "transaction failed");
    }
}