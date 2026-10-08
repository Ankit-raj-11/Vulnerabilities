# Insecure Randomness (SWC-120)

## Overview
In smart contracts, true randomness cannot be generated natively on-chain because the Ethereum Virtual Machine (EVM) is deterministic. Every transaction must yield the exact same result across all validating nodes.

A common pitfall is attempting to generate pseudo-random numbers using block attributes:
- `block.prevrandao` (formerly `block.difficulty`)
- `block.timestamp`
- `block.number`
- Contract balances or address hashes

## Vulnerability (Root Cause)
Because block attributes are publicly readable and identical for every transaction executed within the same block, an attacker contract executing in the same transaction or block can calculate the exact same "random" number. The attacker can then only participate when guaranteed to win or pass the exact expected value, completely draining the contract's prize pool.

## Exploit PoC
In `Exploit.sol`, the `Attacker` contract computes:
```solidity
uint256 winningNumber = uint256(
    keccak256(
        abi.encodePacked(
            block.prevrandao,
            block.timestamp,
            block.number
        )
    )
) % 10;
```
It calls `lottery.play{value: 1 ether}(winningNumber)` in a loop, winning 100% of rounds and draining all jackpot funds.

## Remediation
In `fixed.sol`, the vulnerability is prevented using a **Two-Phase Commit-Reveal Scheme**:
1. **Commit Phase**: The user commits a cryptographic hash `keccak256(abi.encodePacked(secret, guess))` and their bet. The contract records `block.number`.
2. **Reveal Phase**: In a subsequent block (`block.number > commitBlock`), the player reveals their `secret` and `guess`. The outcome is derived using `blockhash(commitBlock)`.
3. **Security**:
   - Because `blockhash(commitBlock)` is not determined until the block is mined, the outcome cannot be predicted when committing.
   - The user cannot commit and reveal in the same block, completely preventing atomic prediction attacks.
   - Alternatively, off-chain verifiable randomness oracles like Chainlink VRF can be used for high-stakes gaming/lottery applications.

## Running Tests
```bash
cd Insecure_Randomness
forge test
```
