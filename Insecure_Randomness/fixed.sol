// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title SecuredLottery
 * @notice Prevents SWC-120 using a two-phase Commit-Reveal scheme.
 * 
 * Mitigation details:
 * 1. Commit Phase: Player commits their guess and a secret salt as a cryptographic hash:
 *    commitment = keccak256(abi.encodePacked(secret, guess)).
 * 2. Reveal Phase: Player reveals the guess and secret in a subsequent block (block.number > commitBlock).
 * 3. Randomness Seed: The outcome is determined using a past block hash (`blockhash(commitBlock)`).
 * 4. Security: 
 *    - An attacker contract cannot predict the outcome at commit time because blockhash(commitBlock)
 *      was unknown at that moment.
 *    - The player cannot reveal in the same block, completely preventing atomic same-transaction exploits.
 */
contract SecuredLottery {
    uint256 public constant BET_AMOUNT = 1 ether;
    uint256 public constant REWARD = 2 ether;

    struct Commitment {
        bytes32 commitmentHash;
        uint256 commitBlock;
        bool revealed;
    }

    mapping(address => Commitment) public commitments;

    constructor() payable {
        require(msg.value >= REWARD, "Need initial prize balance");
    }

    receive() external payable {}

    /**
     * @notice Step 1: Commit to a guess with a secret salt
     * @param _commitmentHash keccak256(abi.encodePacked(secret, guess))
     */
    function commitGuess(bytes32 _commitmentHash) external payable {
        require(msg.value == BET_AMOUNT, "Bet must be 1 ether");
        require(
            commitments[msg.sender].commitBlock == 0 || commitments[msg.sender].revealed,
            "Pending commitment exists"
        );

        commitments[msg.sender] = Commitment({
            commitmentHash: _commitmentHash,
            commitBlock: block.number,
            revealed: false
        });
    }

    /**
     * @notice Step 2: Reveal the guess in a subsequent block
     * @param secret The secret salt chosen by the user
     * @param guess The original guess (0-9)
     */
    function revealGuess(bytes32 secret, uint256 guess) external {
        Commitment storage userCommit = commitments[msg.sender];
        require(userCommit.commitBlock > 0, "No commitment found");
        require(!userCommit.revealed, "Already revealed");
        require(block.number > userCommit.commitBlock, "Cannot reveal in same block");
        require(block.number <= userCommit.commitBlock + 256, "Blockhash expired");

        // Verify that revealed guess and secret match the commitment hash
        bytes32 verifyHash = keccak256(abi.encodePacked(secret, guess));
        require(verifyHash == userCommit.commitmentHash, "Invalid secret or guess");

        userCommit.revealed = true;

        // Use the blockhash of the commit block as seed for randomness
        bytes32 seed = blockhash(userCommit.commitBlock);
        uint256 winningNumber = uint256(keccak256(abi.encodePacked(seed, msg.sender))) % 10;

        if (guess == winningNumber) {
            require(address(this).balance >= REWARD, "Contract out of funds");
            (bool success, ) = msg.sender.call{value: REWARD}("");
            require(success, "Payout failed");
        }
    }

    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
