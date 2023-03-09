// SPDX-License-Identifier: MIT
// by 0xAA
pragma solidity ^0.8.4;

import "./IERC165.sol";
import "./IERC721.sol";
import "./IERC721Receiver.sol";
import "./IERC721Metadata.sol";
import "./Address.sol";
import "./String.sol";
error ERC721_ZeroAddress();
error ERC721_TokenDoesNotExist();
error ERC721_NotOwnerNorApproved();
error ERC721_NotOwner();
error ERC721_NotERC721Receiver(
    address from,
    address to,
    uint tokenId,
    bytes _data
);
error ERC721_AlreadyMinted();
error ERC721_NotOwnerOfToken();

contract ERC721 is IERC721, IERC721Metadata {
    using Address for address; // 使用Address库，用isContract来判断地址是否为合约
    using Strings for uint256; // 使用String库，

    // Token名称
    string public override name;
    // Token代号
    string public override symbol;
    // tokenId 到 owner address 的持有人映射
    mapping(uint => address) private s_owners;
    // address 到 持仓数量 的持仓量映射
    mapping(address => uint) s_balances;
    // tokenID 到 授权地址 的授权映射
    mapping(uint => address) private s_tokenApprovals;
    //  owner地址。到operator地址 的批量授权映射
    mapping(address => mapping(address => bool)) private s_operatorApprovals;

    /**
     * 构造函数，初始化`name` 和`symbol` .
     */
    constructor(string memory name_, string memory symbol_) {
        name = name_;
        symbol = symbol_;
    }

    // 实现IERC165接口supportsInterface
    function supportsInterface(
        bytes4 interfaceId
    ) external pure override returns (bool) {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC165).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId;
    }

    // 实现IERC721的balanceOf，利用_balances变量查询owner地址的balance。
    function balanceOf(address owner) external view override returns (uint) {
        if (owner == address(0)) {
            revert ERC721_ZeroAddress();
        }
        return s_balances[owner];
    }

    // 实现IERC721的ownerOf，利用_owners变量查询tokenId的owner。
    function ownerOf(
        uint tokenId
    ) external view override returns (address owner) {
        owner = s_owners[tokenId];
        if (owner == address(0)) {
            revert ERC721_TokenDoesNotExist();
        }
    }

    // 实现IERC721的isApprovedForAll，利用_operatorApprovals变量查询owner地址是否将所持NFT批量授权给了operator地址。
    function isApprovedForAll(
        address owner,
        address operator
    ) external view override returns (bool) {
        return s_operatorApprovals[owner][operator];
    }

    // 实现IERC721的setApprovalForAll，将持有代币全部授权给operator地址。调用_setApprovalForAll函数。
    function setApprovalForAll(
        address operator,
        bool approved
    ) external override {
        s_operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    // 实现IERC721的getApproved，利用_tokenApprovals变量查询tokenId的授权地址。
    function getApproved(
        uint tokenId
    ) external view override returns (address) {
        if (s_owners[tokenId] == address(0)) {
            revert ERC721_TokenDoesNotExist();
        }
        return s_tokenApprovals[tokenId];
    }

    // 授权函数。通过调整_tokenApprovals来，授权 to 地址操作 tokenId，同时释放Approval事件。 ---private函数，只能合约内部调用
    function _approve(address owner, address to, uint tokenId) private {
        s_tokenApprovals[tokenId] = to;
        emit Approval(owner, to, tokenId);
    }

    // 实现IERC721的approve，将tokenId授权给 to 地址。条件：to不是owner，且msg.sender是owner或授权地址。调用_approve函数。
    function approve(address to, uint tokenId) external override {
        // 这里不能为view 因为这个函数调用了_approve，而_approve里面emit了一个事件
        address owner = s_owners[tokenId]; // 减少gas消耗
        if (msg.sender != owner || !s_operatorApprovals[owner][msg.sender]) {
            revert ERC721_NotOwnerNorApproved();
        }
        _approve(owner, to, tokenId);
    }

    // 查询 spender地址是否可以使用tokenId（需要是owner或被授权地址）
    function _isApprovedOrOwner(
        address owner,
        address spender,
        uint tokenId
    ) private view returns (bool) {
        return (spender == owner ||
            s_tokenApprovals[tokenId] == spender ||
            s_operatorApprovals[owner][spender]);
    }

    /*
     * 转账函数。通过调整_balances和_owner变量将 tokenId 从 from 转账给 to，同时释放Transfer事件。
     * 条件:
     * 1. tokenId 被 from 拥有
     * 2. to 不是0地址
     */
    function _transfer(
        address owner,
        address from,
        address to,
        uint tokenId
    ) private {
        if (from != owner) {
            revert ERC721_NotOwner();
        }
        if (to == address(0)) {
            revert ERC721_ZeroAddress();
        }

        _approve(owner, address(0), tokenId); // 取消之前的所有授权：因为既然这个token被转给某个账户了，那么之前的授权都不作数了!!!!!如果没有这一步，那么这个token被转走之后，其他授权人还可以操作这个token

        s_balances[from] -= 1;
        s_balances[to] += 1;
        s_owners[tokenId] = to;

        emit Transfer(from, to, tokenId);
    }

    // 实现IERC721的transferFrom，非安全转账，不建议使用。调用_transfer函数
    function transferFrom(
        address from,
        address to,
        uint tokenId
    ) external override {
        address owner = ownerOf(tokenId);
        if (!_isApprovedOrOwner(owner, msg.sender, tokenId)) {
            revert ERC721_NotOwnerNorApproved();
        }
        _transfer(owner, from, to, tokenId);
    }

    /**
     * 安全转账，安全地将 tokenId 代币从 from 转移到 to，会检查合约接收者是否了解 ERC721 协议，以防止代币被永久锁定。调用了_transfer函数和_checkOnERC721Received函数。条件：
     * from 不能是0地址.
     * to 不能是0地址.
     * tokenId 代币必须存在，并且被 from拥有.
     * 如果 to 是智能合约, 他必须支持 IERC721Receiver-onERC721Received.
     */
    function _safeTransfer(
        address owner,
        address from,
        address to,
        uint tokenId,
        bytes memory _data
    ) private {
        _transfer(owner, from, to, tokenId);
        if (!_checkOnERC721Received(from, to, tokenId, _data)) {
            revert ERC721_NotERC721Receiver(from, to, tokenId, _data);
        }
    }

    /**
     * 实现IERC721的safeTransferFrom，安全转账，调用了_safeTransfer函数。
     */
    function safeTransferFrom(
        address from,
        address to,
        uint tokenId,
        bytes memory _data
    ) public override {
        address owner = ownerOf(tokenId);
        if (!_isApprovedOrOwner(owner, msg.sender, tokenId)) {
            revert ERC721_NotOwnerNorApproved();
        }

        _safeTransfer(owner, from, to, tokenId, _data);
    }

    // safeTransferFrom重载函数
    function safeTransferFrom(
        address from,
        address to,
        uint tokenId
    ) external override {
        safeTransferFrom(from, to, tokenId, "");
    }

    /**
     * 铸造函数。通过调整_balances和_owners变量来铸造tokenId并转账给 to，同时释放Transfer事件。铸造函数。通过调整_balances和_owners变量来铸造tokenId并转账给 to，同时释放Transfer事件。
     * 这个mint函数所有人都能调用，实际使用需要开发人员重写，加上一些条件。
     * 条件:
     * 1. tokenId尚不存在。
     * 2. to不是0地址.
     */
    function _mint(address to, uint tokenId) internal virtual {
        if (to == address(0)) {
            revert ERC721_ZeroAddress();
        }
        if (s_owners[tokenId] != address(0)) {
            revert ERC721_AlreadyMinted();
        }

        s_balances[to] += 1;
        s_owners[tokenId] = to;

        emit Transfer(address(0), to, tokenId);
    }

    // 销毁函数，通过调整_balances和_owners变量来销毁tokenId，同时释放Transfer事件。条件：tokenId存在。
    function _burn(uint tokenId) internal virtual {
        address owner = ownerOf(tokenId);
        if (msg.sender != owner) {
            revert ERC721_NotOwnerOfToken();
        }
        _approve(owner, address(0), tokenId); // 解除授权

        s_balances[owner] -= 1;
        delete s_owners[tokenId];

        emit Transfer(owner, address(0), tokenId);
    }

    // _checkOnERC721Received：函数，用于在 to 为合约的时候调用IERC721Receiver-onERC721Received, 以防 tokenId 被不小心转入黑洞。
    function _checkOnERC721Received(
        address from,
        address to,
        uint tokenId,
        bytes memory _data
    ) private returns (bool) {
        if (to.isContract()) {
            return
                IERC721Receiver(to).onERC721Received(
                    msg.sender,
                    from,
                    tokenId,
                    _data
                ) == IERC721Receiver.onERC721Received.selector;
        } else {
            return true;
        }
    }

    /**
     * 实现IERC721Metadata的tokenURI函数，查询metadata。
     */
    function tokenURI(
        uint256 tokenId
    ) public view virtual override returns (string memory) {
        if (s_owners[tokenId] == address(0)) {
            revert ERC721_TokenDoesNotExist();
        }

        string memory baseURI = _baseURI();
        return
            bytes(baseURI).length > 0
                ? string(abi.encodePacked(baseURI, tokenId.toString())) // 需要跟合约交互使用encode，不跟合约交互用encodePacked
                : "";
    }

    /**
     * 计算{tokenURI}的BaseURI，tokenURI就是把baseURI和tokenId拼接在一起，需要开发重写。
     * BAYC的baseURI为ipfs://QmeSjSinHpPnmXmspMjwiXyN6zS4E9zccariGR3jxcaWtq/
     */
    function _baseURI() internal view virtual returns (string memory) {
        return "";
    }
}
