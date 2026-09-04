//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../vulnerable.sol";

contract testTreasury is Test{
    Treasury yeld;
    address user = makeAddr("user");

    function setUp() public{
        yeld = new Treasury();
        vm.deal(address(yeld), 5 ether);
        vm.deal(user, 5 ether);
    }
    function testDeposite() public {
        vm.prank(user);
        yeld.deposit{value: 1 ether}();
        assertEq(address(yeld).balance, 6 ether);
        console.log("Treasury balance:", address(yeld).balance);
    }

}



