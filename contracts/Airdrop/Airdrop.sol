// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.4;
import "../ERC20/IERC20.sol";
error Airdrop_LengthNotEqual();
error Airdrop_AllowanceNotEnough();
error Airdrop_NeededETHNotEqual();

contract Airdrop {
    constructor() {}

    // 数组求和
    function getSum(uint256[] calldata arr) public pure returns (uint256 sum) {
        for (uint i = 0; i < arr.length; i++) {
            sum += arr[i];
        }
    }

    function multiTransferToken(
        address tokenAds,
        address[] calldata addresses,
        uint256[] calldata amounts
    ) external {
        if (addresses.length != amounts.length) {
            revert Airdrop_LengthNotEqual();
        }
        IERC20 token = IERC20(tokenAds);
        // 检查代币授权额度
        if (token.allowance(msg.sender, address(this)) < getSum(amounts)) {
            revert Airdrop_AllowanceNotEnough();
        }
        // 代币授权转账
        for (uint i; i < addresses.length; i++) {
            token.transferFrom(msg.sender, addresses[i], amounts[i]);
        }
    }

    function multiTransferETH(
        address[] calldata addresses,
        uint256[] calldata amounts
    ) external payable {
        if (addresses.length != amounts.length) {
            revert Airdrop_LengthNotEqual();
        }
        // 检查转入ETH等于空投总量
        if (msg.value != getSum(amounts)) {
            revert Airdrop_NeededETHNotEqual();
        }
        // for循环，利用transfer函数发送ETH
        for (uint i; i < addresses.length; i++) {
            payable(addresses[i]).transfer(amounts[i]);
        }
    }
}
