// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "./interfaces/IERC20.sol";
import "./interfaces/IERC721.sol";
import "./interfaces/IERC721TokenReceiver.sol";
import "./libraries/StringUtils.sol";

contract ERC721 is IERC721Metadata {
    using StringUtils for uint256;

    bytes4 internal constant _MAGIC_VALUE =
        bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"));

    string public override name;
    string public override symbol;

    string public baseURI;

    address public immutable minter;
    IERC20 public immutable paymentToken;

    uint256 public nftPrice;
    uint256 public lastTokenId;

    mapping(address => uint256) internal _balances;
    mapping(uint256 => address) internal _owners;
    mapping(address => address[]) internal _operators;
    mapping(uint256 => address) internal _approvals;

    constructor(
        string memory name_,
        string memory symbol_,
        string memory baseURI_,
        IERC20 _paymentToken,
        uint256 _initialNftPrice
    ) {
        name = name_;
        symbol = symbol_;
        baseURI = baseURI_;
        minter = msg.sender;
        paymentToken = _paymentToken;
        nftPrice = _initialNftPrice;
    }

    function balanceOf(address account)
        external
        view
        override
        returns (uint256)
    {
        return _balances[account];
    }

    function ownerOf(uint256 tokenId) external view returns (address) {
        return _owners[tokenId];
    }

    function mint(address to) external {
        uint256 tokenId = lastTokenId + 1;
        paymentToken.transferFrom(msg.sender, address(0), nftPrice);
        _balances[to] += 1;
        _owners[tokenId] = to;
        lastTokenId = tokenId;
        nftPrice = (nftPrice * 11) / 10;
        emit Transfer(address(0), to, tokenId);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) public {
        transferFrom(from, to, tokenId);
        if (to.code.length > 0) {
            bytes4 result = IERC721TokenReceiver(to).onERC721Received(
                msg.sender,
                from,
                tokenId,
                data
            );
            require(result == _MAGIC_VALUE, "magic value not returned");
        }
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external {
        safeTransferFrom(from, to, tokenId, bytes(""));
    }

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public {
        address owner = _owners[tokenId];
        require(
            owner == msg.sender ||
                isApprovedForAll(owner, msg.sender) ||
                getApproved(tokenId) == msg.sender,
            "not authorized"
        );

        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[tokenId] = to;
        emit Transfer(from, to, tokenId);
    }

    function approve(address approved, uint256 tokenId) external {
        address owner = _owners[tokenId];
        require(
            msg.sender == owner || isApprovedForAll(owner, msg.sender),
            "not authorized"
        );
        _approvals[tokenId] = approved;
        emit Approval(owner, approved, tokenId);
    }

    function setApprovalForAll(address operator, bool approved) external {
        int256 operatorIndex = _getOperatorIndex(msg.sender, operator);
        bool alreadyApproved = operatorIndex >= 0;
        if (alreadyApproved == approved) return;

        if (approved) {
            _operators[msg.sender].push(operator);
        } else {
            address[] storage userOperators = _operators[msg.sender];
            userOperators[uint256(operatorIndex)] = userOperators[
                userOperators.length - 1
            ];
            userOperators.pop();
        }

        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function isApprovedForAll(address owner, address operator)
        public
        view
        returns (bool)
    {
        return _getOperatorIndex(owner, operator) >= 0;
    }

    function getApproved(uint256 tokenId) public view returns (address) {
        return _approvals[tokenId];
    }

    function tokenURI(uint256 tokenId) external view returns (string memory) {
        return string.concat(baseURI, tokenId.toString());
    }

    function supportsInterface(bytes4 interfaceID)
        external
        pure
        returns (bool)
    {
        return interfaceID == type(IERC721).interfaceId;
    }

    function _getOperatorIndex(address owner, address operator)
        internal
        view
        returns (int256)
    {
        address[] storage userOperators = _operators[owner];
        uint256 operatorsCount = userOperators.length;
        for (uint256 i = 0; i < operatorsCount; i++) {
            if (userOperators[i] == operator) return int256(i);
        }
        return -1;
    }
}