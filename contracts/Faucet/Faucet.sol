// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.4;
import "../ERC20/IERC20.sol";
error Faucet_FaucetEmpty();
error Faucet_RequestMultiple();

contract Faucet {
    uint256 private s_amountAllowed;
    address private s_tokenContract;
    mapping(address => bool) public s_requestedAddress;

    // 定义SendToken事件
    event SendToken(address indexed Receiver, uint256 indexed Amount);

    constructor(uint256 amountAllowed, address tokenContract) {
        s_amountAllowed = amountAllowed;
        s_tokenContract = tokenContract;
    }

    function requestToekens() external OnlyOnce {
        IERC20 token = IERC20(s_tokenContract); // 创建IERC20合约对象
        // 判断token代币在当前合约地址下的代币数量是否足以完成一次发放
        // 而当前合约地址下的代币数量需要通过ERC20代币token的tranfer函数先发放到当前Faucet合约地址下，因此需要先去调用创建好的ERC20合约的transfer函数
        if (token.balanceOf(address(this)) < s_amountAllowed) {
            revert Faucet_FaucetEmpty();
        }
        token.transfer(msg.sender, s_amountAllowed); // 发送token
        s_requestedAddress[msg.sender] = true; // 记录领取地址
        emit SendToken(msg.sender, s_amountAllowed); // 释放SendToken事件
    }

    function getAmountAllowed() external view returns (uint256) {
        return s_amountAllowed;
    }

    function getTokenContract() external view returns (address) {
        return s_tokenContract;
    }

    modifier OnlyOnce() {
        if (s_requestedAddress[msg.sender] == true) {
            revert Faucet_RequestMultiple();
        }
        _;
    }
}
