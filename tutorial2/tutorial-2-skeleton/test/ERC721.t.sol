// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "../src/ERC20.sol";
import "../src/ERC721.sol";
import "../src/interfaces/IERC721TokenReceiver.sol";

contract CompliantReceiver is IERC721TokenReceiver {
    bytes4 internal constant _MAGIC_VALUE =
        bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"));

    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) public pure returns (bytes4) {
        return _MAGIC_VALUE;
    }
}

contract ReceiverWithoutFunction {}

contract ReceiverWithWrongReturnValue is IERC721TokenReceiver {
    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) public pure returns (bytes4) {
        return bytes4(uint32(1));
    }
}

contract BaseERC721Test is Test {
    event Transfer(
        address indexed _from,
        address indexed _to,
        uint256 indexed _tokenId
    );
    event Approval(
        address indexed _owner,
        address indexed _approved,
        uint256 indexed _tokenId
    );
    event ApprovalForAll(
        address indexed _owner,
        address indexed _operator,
        bool _approved
    );

    ERC20 public paymentToken;
    ERC721 public nft;

    uint256 public nftPrice = 1e19;

    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public charlie = makeAddr("charlie");

    function setUp() public {
        paymentToken = new ERC20("Test token", "TST");
        nft = new ERC721(
            "Test NFT",
            "TSN",
            "http://example.com/nft/",
            paymentToken,
            nftPrice
        );
    }

    function _mintNFT(address owner) internal {
        vm.prank(address(this));
        paymentToken.mint(owner, nftPrice);
        vm.prank(owner);
        paymentToken.approve(address(nft), nftPrice);
        vm.prank(owner);
        nft.mint(owner);
    }
}

contract ERC721Test is BaseERC721Test {
    function testName() public {
        assertEq(nft.name(), "Test NFT");
    }

    function testSymbol() public {
        assertEq(nft.symbol(), "TSN");
    }

    function testTokenURI() public {
        assertEq(nft.tokenURI(0), "http://example.com/nft/0");
        assertEq(nft.tokenURI(1), "http://example.com/nft/1");
        assertEq(nft.tokenURI(9), "http://example.com/nft/9");
        assertEq(nft.tokenURI(10), "http://example.com/nft/10");
        assertEq(nft.tokenURI(11), "http://example.com/nft/11");
        assertEq(nft.tokenURI(23), "http://example.com/nft/23");
        assertEq(nft.tokenURI(99), "http://example.com/nft/99");
        assertEq(nft.tokenURI(100), "http://example.com/nft/100");
        assertEq(nft.tokenURI(101), "http://example.com/nft/101");
        assertEq(nft.tokenURI(158), "http://example.com/nft/158");
        assertEq(nft.tokenURI(3874), "http://example.com/nft/3874");
        assertEq(nft.tokenURI(9999), "http://example.com/nft/9999");
        assertEq(nft.tokenURI(10000), "http://example.com/nft/10000");
    }

    function testSuccessfulMint() public {
        paymentToken.mint(alice, nftPrice);
        vm.startPrank(alice);
        paymentToken.approve(address(nft), nftPrice);
        vm.expectEmit(true, true, true, false);
        emit Transfer(address(0), alice, 1);
        nft.mint(alice);
        assertEq(nft.ownerOf(1), alice);
        assertEq(nft.balanceOf(alice), 1);
        assertEq(paymentToken.balanceOf(alice), 0);
    }

    function testMintWithInsufficientBalance() public {
        vm.startPrank(alice);
        paymentToken.approve(address(nft), nftPrice);
        vm.expectRevert("insufficient balance");
        nft.mint(alice);
    }

    function testMintWithInsufficientAllowance() public {
        paymentToken.mint(alice, nftPrice);
        vm.startPrank(alice);
        vm.expectRevert("insufficient allowance");
        nft.mint(alice);
    }

    function testSuccessfulMints() public {
        paymentToken.mint(alice, 1e20);
        vm.startPrank(alice);
        paymentToken.approve(address(nft), nftPrice * 10);
        nft.mint(alice);
        vm.expectEmit(true, true, true, false);
        emit Transfer(address(0), alice, 2);
        nft.mint(alice);
        assertEq(nft.ownerOf(2), alice);
        assertEq(nft.balanceOf(alice), 2);
        assertEq(
            paymentToken.balanceOf(alice),
            1e20 - nftPrice - (nftPrice * 11) / 10
        );
    }

    function testApprove() public {
        _mintNFT(alice);
        vm.startPrank(alice);
        vm.expectEmit(true, true, true, false);
        emit Approval(alice, charlie, 1);
        nft.approve(charlie, 1);
        assertEq(nft.getApproved(1), charlie);
        nft.approve(address(0), 1);
        assertEq(nft.getApproved(1), address(0));
    }

    function testApproveUnauthorized() public {
        vm.startPrank(bob);
        vm.expectRevert("not authorized");
        nft.approve(charlie, 1);
    }

    function testTransferFromOwner() public {
        _mintNFT(alice);
        vm.prank(alice);
        vm.expectEmit(true, true, true, false);
        emit Transfer(alice, bob, 1);
        nft.transferFrom(alice, bob, 1);
        assertEq(nft.ownerOf(1), bob);
    }

    function testTransferFromApproved() public {
        _mintNFT(alice);
        vm.prank(alice);
        nft.approve(charlie, 1);
        vm.prank(charlie);
        vm.expectEmit(true, true, true, false);
        emit Transfer(alice, bob, 1);
        nft.transferFrom(alice, bob, 1);
        assertEq(nft.ownerOf(1), bob);
    }

    function testTransferFromManager() public {
        _mintNFT(alice);
        vm.prank(alice);
        nft.setApprovalForAll(charlie, true);
        vm.prank(charlie);
        vm.expectEmit(true, true, true, false);
        emit Transfer(alice, bob, 1);
        nft.transferFrom(alice, bob, 1);
        assertEq(nft.ownerOf(1), bob);
    }
}

contract BonusERC721Test is BaseERC721Test {
    function testSafeTransferToEOA() public {
        _mintNFT(alice);
        vm.prank(alice);
        nft.setApprovalForAll(charlie, true);
        vm.prank(charlie);
        vm.expectEmit(true, true, true, false);
        emit Transfer(alice, bob, 1);
        nft.safeTransferFrom(alice, bob, 1);
        assertEq(nft.ownerOf(1), bob);
    }

    function testSafeTransferToCompliantContract() public {
        _mintNFT(alice);
        address receiver = address(new CompliantReceiver());
        vm.prank(alice);
        nft.safeTransferFrom(alice, receiver, 1);
        assertEq(nft.ownerOf(1), receiver);
    }

    function testSafeTransferToContractMissingFunction() public {
        _mintNFT(alice);
        address receiver = address(new ReceiverWithoutFunction());
        vm.prank(alice);
        vm.expectRevert();
        nft.safeTransferFrom(alice, receiver, 1);
    }

    function testSafeTransferToContractWrongReturnValue() public {
        _mintNFT(alice);
        address receiver = address(new ReceiverWithWrongReturnValue());
        vm.prank(alice);
        vm.expectRevert("magic value not returned");
        nft.safeTransferFrom(alice, receiver, 1);
    }

    function testSetApproveAll() public {
        vm.prank(alice);
        vm.expectEmit(true, true, false, true);
        emit ApprovalForAll(alice, charlie, true);
        nft.setApprovalForAll(charlie, true);
        assertTrue(nft.isApprovedForAll(alice, charlie));
    }

    function testSetApproveAllTwice() public {
        vm.startPrank(alice);
        vm.expectEmit(true, true, false, true);
        emit ApprovalForAll(alice, charlie, true);
        nft.setApprovalForAll(charlie, true);
        assertTrue(nft.isApprovedForAll(alice, charlie));
        nft.setApprovalForAll(charlie, true);
        assertTrue(nft.isApprovedForAll(alice, charlie));
    }

    function testSetApproveAllFalseAfterSingleAdd() public {
        vm.startPrank(alice);
        nft.setApprovalForAll(charlie, true);
        assertTrue(nft.isApprovedForAll(alice, charlie));
        nft.setApprovalForAll(charlie, false);
        assertFalse(nft.isApprovedForAll(alice, charlie));
    }

    function testSetApproveAllFalseAfterTwoAdd() public {
        vm.startPrank(alice);
        nft.setApprovalForAll(charlie, true);
        assertTrue(nft.isApprovedForAll(alice, charlie));
        nft.setApprovalForAll(charlie, true);
        assertTrue(nft.isApprovedForAll(alice, charlie));
        nft.setApprovalForAll(charlie, false);
        assertFalse(nft.isApprovedForAll(alice, charlie));
    }

    function testSupportsInterface() public {
        // ERC721 should have interface id 0x80ac58cd
        assertTrue(nft.supportsInterface(0x80ac58cd));
        assertFalse(nft.supportsInterface(0x60ac58cd));
    }
}
