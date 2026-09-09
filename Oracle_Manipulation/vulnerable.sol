// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MockToken {
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

contract SimpleDEX {
    MockToken public tokenA;
    MockToken public tokenB;

    constructor(address _tokenA, address _tokenB) {
        tokenA = MockToken(_tokenA);
        tokenB = MockToken(_tokenB);
    }

    function getReserves() public view returns (uint256 reserveA, uint256 reserveB) {
        reserveA = tokenA.balanceOf(address(this));
        reserveB = tokenB.balanceOf(address(this));
    }

    // Spot price of Token B in terms of Token A (scaled by 1e18)
    function getSpotPrice() public view returns (uint256) {
        (uint256 reserveA, uint256 reserveB) = getReserves();
        require(reserveB > 0, "DEX: empty reserve");
        return (reserveA * 1e18) / reserveB;
    }

    // Swap tokenIn for the other token using constant product x * y = k formula
    function swap(address tokenIn, uint256 amountIn) external returns (uint256 amountOut) {
        require(tokenIn == address(tokenA) || tokenIn == address(tokenB), "Invalid token");
        require(amountIn > 0, "Zero amount");

        bool isTokenA = tokenIn == address(tokenA);
        (MockToken inputToken, MockToken outputToken) = isTokenA
            ? (tokenA, tokenB)
            : (tokenB, tokenA);

        (uint256 reserveIn, uint256 reserveOut) = isTokenA
            ? (tokenA.balanceOf(address(this)), tokenB.balanceOf(address(this)))
            : (tokenB.balanceOf(address(this)), tokenA.balanceOf(address(this)));

        inputToken.transferFrom(msg.sender, address(this), amountIn);

        // Calculate output: dx * y / (x + dx)
        amountOut = (amountIn * reserveOut) / (reserveIn + amountIn);
        require(amountOut > 0, "Zero output");

        outputToken.transfer(msg.sender, amountOut);
    }
}

contract VulnerableLendingPool {
    MockToken public borrowToken; // Token A
    MockToken public collateralToken; // Token B
    SimpleDEX public dex;

    mapping(address => uint256) public collateralBalance;
    mapping(address => uint256) public borrowedAmount;

    // Loan-to-value: 80% (80 / 100)
    uint256 public constant LTV = 80;

    constructor(address _borrowToken, address _collateralToken, address _dex) {
        borrowToken = MockToken(_borrowToken);
        collateralToken = MockToken(_collateralToken);
        dex = SimpleDEX(_dex);
    }

    function depositCollateral(uint256 amount) external {
        require(amount > 0, "Amount must be > 0");
        collateralToken.transferFrom(msg.sender, address(this), amount);
        collateralBalance[msg.sender] += amount;
    }

    // VULNERABILITY: Relying on spot AMM price from SimpleDEX directly
    function borrow(uint256 amount) external {
        uint256 userCollateral = collateralBalance[msg.sender];
        require(userCollateral > 0, "No collateral");

        // Vulnerable spot price query (manipulatable via large swaps / flash loans)
        uint256 spotPrice = dex.getSpotPrice();

        // Collateral value in terms of borrowToken (Token A)
        uint256 collateralValueInA = (userCollateral * spotPrice) / 1e18;
        uint256 maxBorrow = (collateralValueInA * LTV) / 100;

        require(borrowedAmount[msg.sender] + amount <= maxBorrow, "Exceeds max borrow limit");

        borrowedAmount[msg.sender] += amount;
        require(borrowToken.transfer(msg.sender, amount), "Transfer failed");
    }
}
