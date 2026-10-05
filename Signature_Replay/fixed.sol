// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract SecuredVault {
    address public owner;
    mapping(address => uint256) public nonces;

    constructor() payable {
        owner = msg.sender;
    }

    function deposit() external payable {}

    // FIX:
    // 1. Include `address(this)` and `block.chainid` to prevent cross-contract and cross-chain replay.
    // 2. Include a user nonce to invalidate the signature once used.
    function withdrawWithSignature(
        address to,
        uint256 amount,
        uint256 nonce,
        bytes memory signature
    ) external {
        require(address(this).balance >= amount, "Insufficient funds");
        require(nonce == nonces[to], "Invalid nonce");

        // Increment nonce BEFORE external call to prevent replay
        nonces[to]++;

        bytes32 messageHash = getMessageHash(to, amount, nonce);
        bytes32 ethSignedMessageHash = getEthSignedMessageHash(messageHash);

        require(recoverSigner(ethSignedMessageHash, signature) == owner, "Invalid signature");

        (bool success, ) = to.call{value: amount}("");
        require(success, "Transfer failed");
    }

    function getMessageHash(
        address to,
        uint256 amount,
        uint256 nonce
    ) public view returns (bytes32) {
        return keccak256(abi.encodePacked(address(this), block.chainid, to, amount, nonce));
    }

    function getEthSignedMessageHash(bytes32 _messageHash) public pure returns (bytes32) {
        return keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", _messageHash)
        );
    }

    function recoverSigner(
        bytes32 _ethSignedMessageHash,
        bytes memory _sig
    ) public pure returns (address) {
        (bytes32 r, bytes32 s, uint8 v) = splitSignature(_sig);
        return ecrecover(_ethSignedMessageHash, v, r, s);
    }

    function splitSignature(bytes memory sig) public pure returns (bytes32 r, bytes32 s, uint8 v) {
        require(sig.length == 65, "Invalid signature length");

        assembly {
            r := mload(add(sig, 32))
            s := mload(add(sig, 64))
            v := byte(0, mload(add(sig, 96)))
        }
    }

    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
