//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../vulnerable.sol";
import "../Exploit.sol";
import "../fixed.sol";

contract Reentrancy is Test {
     VulnerableBank bank;
     Attacker attacker;

     address user = makeAddr("user");

    function setUp() public {
        bank = new VulnerableBank();
        attacker = new Attacker(address(bank));
        vm.deal(address(bank), 10 ether);
        vm.deal(user, 1 ether);
    }

  function testReentrancyAttack() public {
        uint256 bankBefore = address(bank).balance;
        uint256 attackerBefore = address(attacker).balance;

        vm.prank(user);
        attacker.attack{value: 1 ether}();

        uint256 bankAfter = address(bank).balance;
        uint256 attackerAfter = address(attacker).balance;

        assertLt(bankAfter, bankBefore);
        assertGt(attackerAfter, attackerBefore);
    }
}