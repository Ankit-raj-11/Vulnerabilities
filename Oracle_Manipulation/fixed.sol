// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./vulnerable.sol";

interface IPriceFeed {
    function getLatestPrice() external view returns (uint256, uint256 updatedAt);
}

// Mock Chainlink / Decentralized Price Feed
contract MockChainlinkPriceFeed is IPriceFeed {
    uint256 private price;
    uint256 private lastUpdatedAt;

    constructor(uint256 _initialPrice) {
        price = _initialPrice;
        lastUpdatedAt = block.timestamp;
    }

    function setPrice(uint256 _newPrice) external {
        price = _newPrice;
        lastUpdatedAt = block.timestamp;
    }

    function getLatestPrice() external view override returns (uint256, uint256) {
        return (price, lastUpdatedAt);
    }
}

contract SecureLendingPool {
    MockToken public borrowToken; // Token A
    MockToken public collateralToken; // Token B
    IPriceFeed public priceFeed;

    mapping(address => uint256) public collateralBalance;
    mapping(address => uint256) public borrowedAmount;

    uint256 public constant LTV = 80; // 80%
    uint256 public constant STALE_PRICE_TIMEOUT = 1 hours;

    constructor(address _borrowToken, address _collateralToken, address _priceFeed) {
        borrowToken = MockToken(_borrowToken);
        collateralToken = MockToken(_collateralToken);
        priceFeed = IPriceFeed(_priceFeed);
    }

    function depositCollateral(uint256 amount) external {
        require(amount > 0, "Amount must be > 0");
        collateralToken.transferFrom(msg.sender, address(this), amount);
        collateralBalance[msg.sender] += amount;
    }

    // FIX: Uses decentralized Chainlink / Time-Weighted price oracle with freshness check
    // Immunized against single-transaction flash loan / spot pool manipulation
    function borrow(uint256 amount) external {
        uint256 userCollateral = collateralBalance[msg.sender];
        require(userCollateral > 0, "No collateral");

        (uint256 oraclePrice, uint256 updatedAt) = priceFeed.getLatestPrice();
        require(oraclePrice > 0, "Invalid price");
        require(block.timestamp - updatedAt <= STALE_PRICE_TIMEOUT, "Stale price feed");

        // Calculate collateral value using secure oracle price
        uint256 collateralValueInA = (userCollateral * oraclePrice) / 1e18;
        uint256 maxBorrow = (collateralValueInA * LTV) / 100;

        require(borrowedAmount[msg.sender] + amount <= maxBorrow, "Exceeds max borrow limit");

        borrowedAmount[msg.sender] += amount;
        require(borrowToken.transfer(msg.sender, amount), "Transfer failed");
    }
}
