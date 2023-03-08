// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.4;
import "./IERC20.sol";
error ERC20_NOTOWNER(address owner);

contract ERC20 is IERC20 {
    mapping(address => uint256) public override balanceOf;
    mapping(address => mapping(address => uint256)) public override allowance;
    uint256 public override totalSupply; // 代币总供给
    string private s_name;
    string private s_symbol;
    uint256 private s_decimals;
    address private s_owner;

    constructor(string memory name, string memory symbol, uint256 decimals) {
        s_name = name;
        s_symbol = symbol;
        s_decimals = decimals;
        s_owner = msg.sender;
    }

    function transfer(
        address to,
        uint256 amount
    ) external override returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function approve(
        address spender,
        uint256 amount
    ) external override returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    /**
     * @dev 调用者msg.sender是被授权人.这个函数是被授权人(msg.sender)调用，扣除授权人(from)给被授权人(msg.sender)的授权额度，把授权人(from)的部分余额转给接收者(to)
     * @param from 授权人
     * @param to 接收者
     * @param amount 代币数量
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external override returns (bool isSuccess) {
        allowance[from][msg.sender] -= amount; // from授权给此函数调用者的额度减少amount
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount); // 触发转账操作
        isSuccess = true;
    }

    function getName() public view returns (string memory) {
        return s_name;
    }

    function getSymbol() public view returns (string memory) {
        return s_symbol;
    }

    function getDecimals() public view returns (uint256) {
        return s_decimals;
    }

    function mint(uint256 amount) external OnlyOwner {
        balanceOf[msg.sender] += amount;
        totalSupply += amount;
        emit Transfer(address(0), msg.sender, amount);
    }

    function burn(uint256 amount) external {
        balanceOf[msg.sender] -= amount;
        totalSupply -= amount;
        emit Transfer(msg.sender, address(0), amount);
    }

    modifier OnlyOwner() {
        require(msg.sender == s_owner);
        _;
    }
}
