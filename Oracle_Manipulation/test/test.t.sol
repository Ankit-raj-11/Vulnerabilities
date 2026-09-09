// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../vulnerable.sol";
import "../Exploit.sol";
import "../fixed.sol";

contract OracleManipulationTest is Test {
    MockToken tokenA; // Borrow Token (e.g. USDC / DAI)
    MockToken tokenB; // Collateral Token (e.g. WETH)
    SimpleDEX dex;
    VulnerableLendingPool vulnerablePool;
    SecureLendingPool securePool;
    MockChainlinkPriceFeed priceFeed;
    OracleAttacker attackerContract;

    address owner = makeAddr("owner");
    address attacker = makeAddr("attacker");
    address liquidityProvider = makeAddr("lp");

    function setUp() public {
        tokenA = new MockToken("Token A", "TKNA");
        tokenB = new MockToken("Token B", "TKNB");

        // Deploy DEX and Lending Pools
        dex = new SimpleDEX(address(tokenA), address(tokenB));
        vulnerablePool = new VulnerableLendingPool(address(tokenA), address(tokenB), address(dex));

        // Secure feed has fair price 1 Token B = 1 Token A (1e18)
        priceFeed = new MockChainlinkPriceFeed(1 ether);
        securePool = new SecureLendingPool(address(tokenA), address(tokenB), address(priceFeed));

        attackerContract = new OracleAttacker(
            address(tokenA),
            address(tokenB),
            address(dex),
            address(vulnerablePool)
        );

        // Fund Liquidity Provider
        tokenA.mint(liquidityProvider, 500_000 ether);
        tokenB.mint(liquidityProvider, 500_000 ether);

        // 1. LP adds initial liquidity to DEX: 10,000 A & 10,000 B (Price = 1:1)
        vm.startPrank(liquidityProvider);
        tokenA.approve(address(dex), 10_000 ether);
        tokenB.approve(address(dex), 10_000 ether);
        tokenA.transfer(address(dex), 10_000 ether);
        tokenB.transfer(address(dex), 10_000 ether);

        // 2. LP deposits 100,000 Token A into both lending pools
        tokenA.transfer(address(vulnerablePool), 100_000 ether);
        tokenA.transfer(address(securePool), 100_000 ether);
        vm.stopPrank();

        // 3. Attacker starts with 90,000 Token A (e.g. from flash loan)
        tokenA.mint(attacker, 90_000 ether);
    }

    function testSpotPriceManipulationExploit() public {
        uint256 poolBalanceBefore = tokenA.balanceOf(address(vulnerablePool));
        uint256 attackerTokenABefore = tokenA.balanceOf(attacker);

        assertEq(poolBalanceBefore, 100_000 ether);

        // Attacker runs exploit
        vm.startPrank(attacker);
        tokenA.approve(address(attackerContract), 90_000 ether);

        // Swap 90,000 Token A into DEX, pump Token B price, deposit received Token B, drain pool
        attackerContract.attack(90_000 ether);
        vm.stopPrank();

        uint256 poolBalanceAfter = tokenA.balanceOf(address(vulnerablePool));
        uint256 attackerTokenAAfter = tokenA.balanceOf(attacker);

        console.log("Vulnerable Pool Balance After Drain:", poolBalanceAfter);
        console.log("Attacker Token A Balance After:", attackerTokenAAfter);

        // Vulnerable pool was completely drained of all Token A
        assertEq(poolBalanceAfter, 0);
        // Attacker made a net profit (100,000 borrowed - 90,000 spent = 10,000 profit + collateral)
        assertGt(attackerTokenAAfter, attackerTokenABefore);
        assertEq(attackerTokenAAfter, 100_000 ether);
    }

    function testSecureOraclePreventsExploit() public {
        // Manipulate the DEX spot price similarly
        vm.startPrank(attacker);
        tokenA.approve(address(dex), 90_000 ether);
        dex.swap(address(tokenA), 90_000 ether);

        // Attempt to deposit small collateral into Secure Pool and borrow 100,000 Token A
        tokenB.approve(address(securePool), 150 ether);
        securePool.depositCollateral(150 ether);

        // Attempting to borrow more than fair oracle value (150 * 1 ether * 80% = 120 Token A) fails
        vm.expectRevert("Exceeds max borrow limit");
        securePool.borrow(100_000 ether);

        // Borrowing within fair valuation succeeds
        securePool.borrow(120 ether);
        assertEq(tokenA.balanceOf(attacker), 120 ether);
        vm.stopPrank();
    }
}
