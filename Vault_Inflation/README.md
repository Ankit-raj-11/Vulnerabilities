# Vault Share Inflation (First Deposit Attack)

## Overview
The **Vault Share Inflation Attack** (commonly known as the *First Deposit Bug* or *ERC-4626 Share Inflation*) is an arithmetic rounding exploit affecting tokenized vaults and liquidity pools.

In standard vault implementations, shares minted for a deposit are determined by:
$$\text{shares} = \frac{\text{assets} \times \text{totalSupply}}{\text{totalAssets}}$$

## Root Cause
When the vault is empty (`totalSupply == 0`), the initial depositor receives shares at a 1:1 ratio. 
Because Solidity performs integer division with truncation toward zero, an attacker can artificially inflate the price per share by donating assets directly to the contract. When subsequent victims deposit amounts lower than the inflated share price, their share calculation truncates down to `0`.

## Attack Vector
1. **Initial Deposit**: Attacker deposits $1\text{ wei}$ of assets when `totalSupply == 0`, receiving $1\text{ share}$.
2. **Direct Donation**: Attacker transfers $100\text{ ETH}$ directly to the vault contract without minting shares.
   - $\text{totalSupply} = 1\text{ share}$
   - $\text{totalAssets} = 100\text{ ETH} + 1\text{ wei}$
   - The value of $1\text{ share}$ is now $\approx 100\text{ ETH}$.
3. **Victim Deposit**: A victim deposits $50\text{ ETH}$:
   $$\text{shares} = \frac{50\text{ ETH} \times 1}{100\text{ ETH} + 1} = 0$$
   The victim transfers $50\text{ ETH}$ to the vault and receives $0\text{ shares}$.
4. **Theft**: Attacker redeems their $1\text{ share}$, receiving all $150\text{ ETH} + 1\text{ wei}$ from the vault, stealing the victim's entire deposit!

## Remediation
In `fixed.sol`, the vulnerability is solved using **Virtual Shares & Virtual Assets (Decimals Offset)**, the industry standard adopted by OpenZeppelin ERC-4626 (v4.9+):
$$\text{shares} = \frac{\text{assets} \times (\text{totalSupply} + 10^{\text{offset}})}{\text{totalAssets} + 1}$$

- Virtual shares ($10^{\text{offset}} = 1000$) ensure that initial deposits mint substantial shares and cannot be manipulated with small token donations.
- In addition, vaults should enforce `require(shares > 0, "Zero shares minted")` to prevent zero-share loss.
- An alternative solution is **Dead Shares** (burning the first 1,000 shares to `address(0)` upon initialization), as practiced by Uniswap V2.

## Running Tests
```bash
cd Vault_Inflation
forge test
```
