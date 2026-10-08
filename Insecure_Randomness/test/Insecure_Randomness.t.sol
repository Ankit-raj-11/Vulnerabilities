// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import "../vulnerable.sol";
import "../Exploit.sol";
import "../fixed.sol";

contract InsecureRandomnessTest is Test {
    VulnerableLottery public vulnerableLottery;
    SecuredLottery public securedLottery;
    Attacker public attackerContract;

    address internal deployer = makeAddr("deployer");
    address internal player = makeAddr("player");
    address internal attacker = makeAddr("attacker");

    function setUp() public {
        vm.deal(deployer, 50 ether);
        vm.deal(player, 10 ether);
        vm.deal(attacker, 5 ether);

        vm.startPrank(deployer);
        vulnerableLottery = new VulnerableLottery{value: 10 ether}();
        securedLottery = new SecuredLottery{value: 10 ether}();
        vm.stopPrank();

        vm.prank(attacker);
        attackerContract = new Attacker(address(vulnerableLottery));
    }

    function test_insecureRandomnessDrainExploit() public {
        uint256 lotteryBalanceBefore = vulnerableLottery.getBalance();
        assertEq(lotteryBalanceBefore, 10 ether);

        // Attacker executes exploit: precalculates winning number every time and drains the jackpot
        vm.prank(attacker);
        attackerContract.drainLottery{value: 1 ether}();

        uint256 lotteryBalanceAfter = vulnerableLottery.getBalance();
        uint256 attackerContractBalance = attackerContract.getBalance();

        console.log("Vulnerable Lottery balance after exploit:", lotteryBalanceAfter);
        console.log("Attacker contract balance after exploit:", attackerContractBalance);

        // Entire prize pool drained!
        assertEq(lotteryBalanceAfter, 0);
        assertEq(attackerContractBalance, 11 ether); // 1 ether initial bet + 10 ether drained
    }

    function test_securedLotteryPreventsAtomicPrediction() public {
        bytes32 secret = keccak256(abi.encodePacked("my_secret_salt"));
        uint256 guess = 7;
        bytes32 commitmentHash = keccak256(abi.encodePacked(secret, guess));

        vm.startPrank(player);
        // 1. Commit guess
        securedLottery.commitGuess{value: 1 ether}(commitmentHash);

        // 2. Same-block reveal must revert
        vm.expectRevert("Cannot reveal in same block");
        securedLottery.revealGuess(secret, guess);

        // 3. Roll block forward to make prediction unpredictable at commit time
        vm.roll(block.number + 5);

        // 4. Reveal with tampered secret/guess fails
        vm.expectRevert("Invalid secret or guess");
        securedLottery.revealGuess(keccak256(abi.encodePacked("wrong")), guess);

        // 5. Honest reveal succeeds without reverting
        securedLottery.revealGuess(secret, guess);
        vm.stopPrank();
    }
}
