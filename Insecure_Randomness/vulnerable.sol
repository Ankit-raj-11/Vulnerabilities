// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title VulnerableLottery
 * @notice Demonstrates SWC-120 (Weak Sources of Randomness from Chain Attributes).
 * 
 * Vulnerability explanation:
 * The contract generates pseudo-random numbers using block attributes like block.prevrandao,
 * block.timestamp, and block.number. Because these values are publicly known and identical
 * for all transactions executed within the same block, an attacking smart contract can
 * compute the exact "random" number in the same transaction and guarantee a win every single time.
 */
contract VulnerableLottery {
    uint256 public constant BET_AMOUNT = 1 ether;
    uint256 public constant REWARD = 2 ether;

    constructor() payable {
        require(msg.value >= REWARD, "Need initial prize balance");
    }

    receive() external payable {}

    /**
     * @notice Vulnerable pseudo-random number generator using on-chain block variables
     * @return uint256 Random number (0 to 9)
     */
    function _getRandomNumber() internal view returns (uint256) {
        return uint256(
            keccak256(
                abi.encodePacked(
                    block.prevrandao,
                    block.timestamp,
                    block.number
                )
            )
        ) % 10;
    }

    /**
     * @notice Players guess a number between 0 and 9. If correct, they win double their bet.
     * @param guess The player's guessed number (0-9)
     */
    function play(uint256 guess) external payable {
        require(msg.value == BET_AMOUNT, "Bet must be exactly 1 ether");
        require(guess < 10, "Guess must be 0-9");
        require(address(this).balance >= REWARD, "Contract out of funds");

        uint256 winningNumber = _getRandomNumber();

        // If the player guesses correctly, send reward
        if (guess == winningNumber) {
            (bool success, ) = msg.sender.call{value: REWARD}("");
            require(success, "Payout failed");
        }
    }

    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
