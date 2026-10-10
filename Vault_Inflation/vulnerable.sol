// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title MockERC20
 * @notice Simple ERC20 token used for testing vault deposits and withdrawals.
 */
contract MockERC20 {
    string public name;
    string public symbol;
    uint8 public decimals = 18;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
    }

    function mint(address to, uint256 amount) external {
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "ERC20: insufficient balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            require(allowed >= amount, "ERC20: insufficient allowance");
            allowance[from][msg.sender] = allowed - amount;
        }
        require(balanceOf[from] >= amount, "ERC20: insufficient balance");
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
        return true;
    }
}

/**
 * @title VulnerableVault
 * @notice Simplified yield/share vault (ERC-4626 style) vulnerable to the Share Inflation Attack
 * (also known as First Deposit Bug or Rounding Truncation Exploitation).
 *
 * Vulnerability Explanation:
 * The conversion of assets to shares is computed as:
 *     shares = (assets * totalSupply) / totalAssets()
 *
 * An attacker can perform the following exploit:
 * 1. Deposit 1 wei of assets when the vault is empty (totalSupply == 0) -> gets 1 share.
 * 2. Directly transfer (donate) 100 ether of the asset directly to the vault contract.
 *    Now: totalSupply = 1 share, totalAssets = 100 ether + 1 wei.
 *    1 share is now worth ~100 ether!
 * 3. A victim deposits 50 ether. The formula calculates:
 *    shares = (50 ether * 1) / (100 ether + 1 wei) = 0 (integer division rounds down to 0).
 *    The victim transfers 50 ether to the vault and receives 0 shares.
 * 4. The attacker withdraws their 1 share:
 *    assets = (1 * (150 ether + 1 wei)) / 1 = 150 ether + 1 wei.
 *    The attacker steals the victim's entire 50 ether deposit!
 */
contract VulnerableVault {
    MockERC20 public immutable asset;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;

    event Deposit(address indexed sender, address indexed receiver, uint256 assets, uint256 shares);
    event Withdraw(address indexed sender, address indexed receiver, uint256 assets, uint256 shares);

    constructor(address _asset) {
        asset = MockERC20(_asset);
    }

    function totalAssets() public view returns (uint256) {
        return asset.balanceOf(address(this));
    }

    function convertToShares(uint256 assets) public view returns (uint256) {
        uint256 supply = totalSupply;
        return supply == 0 ? assets : (assets * supply) / totalAssets();
    }

    function convertToAssets(uint256 shares) public view returns (uint256) {
        uint256 supply = totalSupply;
        return supply == 0 ? shares : (shares * totalAssets()) / supply;
    }

    /**
     * @notice Deposit assets into the vault to receive shares.
     * VULNERABLE: Does not enforce min shares minted or virtual offset.
     */
    function deposit(uint256 assets, address receiver) external returns (uint256 shares) {
        shares = convertToShares(assets);

        require(asset.transferFrom(msg.sender, address(this), assets), "Transfer failed");

        totalSupply += shares;
        balanceOf[receiver] += shares;

        emit Deposit(msg.sender, receiver, assets, shares);
    }

    /**
     * @notice Withdraw assets by redeeming shares.
     */
    function withdraw(uint256 shares, address receiver) external returns (uint256 assets) {
        require(balanceOf[msg.sender] >= shares, "Insufficient shares");

        assets = convertToAssets(shares);

        balanceOf[msg.sender] -= shares;
        totalSupply -= shares;

        require(asset.transfer(receiver, assets), "Transfer failed");

        emit Withdraw(msg.sender, receiver, assets, shares);
    }
}
