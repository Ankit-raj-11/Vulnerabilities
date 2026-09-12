// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Lib {
    address public owner;

    function pwn() public {
        owner = msg.sender;
    }
}

contract VulnerableProxy {
    address public owner;
    address public lib;

    constructor(address _lib) {
        owner = msg.sender;
        lib = _lib;
    }

    fallback() external payable {
        // VULNERABLE: Arbitrary delegatecall with user-controlled msg.data.
        // delegatecall runs the logic of `lib` in the storage context of `VulnerableProxy`.
        // Calling pwn() will overwrite storage slot 0 (owner) of this contract with msg.sender.
        (bool success, ) = lib.delegatecall(msg.data);
        require(success, "Delegatecall failed");
    }

    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
