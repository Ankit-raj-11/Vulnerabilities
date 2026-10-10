// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./vulnerable.sol";

/**
 * @title SecuredVault
 * @notice Fixed vault implementation protected against the Share Inflation / First Deposit attack.
 *
 * Mitigations Implemented:
 * 1. Virtual Shares and Virtual Assets (Decimals Offset - OpenZeppelin ERC-4626 Standard):
 *    Adds virtual shares (10 ** _decimalsOffset()) and 1 virtual asset to the conversion formula:
 *        shares = (assets * (totalSupply + 10 ** offset)) / (totalAssets() + 1)
 *    This ensures that 1 share cannot be artificially inflated to an enormous asset value by donating,
 *    because the virtual shares dilute any price manipulation.
 *
 * 2. Strict Non-Zero Share Enforcement:
 *    Ensures deposits never succeed if rounding results in 0 shares minted.
 */
contract SecuredVault {
    MockERC20 public immutable asset;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;

    uint8 public constant DECIMALS_OFFSET = 3; // 1,000 virtual shares

    event Deposit(address indexed sender, address indexed receiver, uint256 assets, uint256 shares);
    event Withdraw(address indexed sender, address indexed receiver, uint256 assets, uint256 shares);

    constructor(address _asset) {
        asset = MockERC20(_asset);
    }

    function totalAssets() public view returns (uint256) {
        return asset.balanceOf(address(this));
    }

    function _virtualOffset() internal pure returns (uint256) {
        return 10 ** DECIMALS_OFFSET;
    }

    /**
     * @notice Converts assets to shares using virtual shares and virtual assets.
     */
    function convertToShares(uint256 assets) public view returns (uint256) {
        return (assets * (totalSupply + _virtualOffset())) / (totalAssets() + 1);
    }

    /**
     * @notice Converts shares to assets using virtual shares and virtual assets.
     */
    function convertToAssets(uint256 shares) public view returns (uint256) {
        return (shares * (totalAssets() + 1)) / (totalSupply + _virtualOffset());
    }

    /**
     * @notice Secure deposit enforcing positive shares and virtual scale protection.
     */
    function deposit(uint256 assets, address receiver) external returns (uint256 shares) {
        shares = convertToShares(assets);
        require(shares > 0, "Zero shares minted");

        require(asset.transferFrom(msg.sender, address(this), assets), "Transfer failed");

        totalSupply += shares;
        balanceOf[receiver] += shares;

        emit Deposit(msg.sender, receiver, assets, shares);
    }

    /**
     * @notice Secure withdraw redeeming shares for assets.
     */
    function withdraw(uint256 shares, address receiver) external returns (uint256 assets) {
        require(balanceOf[msg.sender] >= shares, "Insufficient shares");

        assets = convertToAssets(shares);
        require(assets > 0, "Zero assets withdrawn");

        balanceOf[msg.sender] -= shares;
        totalSupply -= shares;

        require(asset.transfer(receiver, assets), "Transfer failed");

        emit Withdraw(msg.sender, receiver, assets, shares);
    }
}
