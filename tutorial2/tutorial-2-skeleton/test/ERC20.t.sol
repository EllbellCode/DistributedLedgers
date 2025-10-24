// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "../src/ERC20.sol";

contract ERC20Test is Test {
    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(
        address indexed _owner,
        address indexed _spender,
        uint256 _value
    );

    ERC20 public token;

    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public charlie = makeAddr("charlie");

    function setUp() public {
        token = new ERC20("Test token", "TST");
    }

    function testName() public {
        assertEq(token.name(), "Test token");
    }

    function testSymbol() public {
        assertEq(token.symbol(), "TST");
    }

    function testDecimals() public {
        assertEq(token.decimals(), 18);
    }

    function testMintAsMinter() public {
        assertEq(token.balanceOf(alice), 0);
        assertEq(token.totalSupply(), 0);
        token.mint(alice, 1e19);
        assertEq(token.balanceOf(alice), 1e19);
        assertEq(token.totalSupply(), 1e19);
    }

    function testMintAsNonMinter() public {
        vm.prank(alice);
        vm.expectRevert("only minter can mint");
        token.mint(alice, 1e19);
    }

    function testTransfer() public {
        token.mint(alice, 1e19);
        vm.prank(alice);
        vm.expectEmit(true, true, false, true);
        emit Transfer(alice, bob, 1e18);
        token.transfer(bob, 1e18);
        assertEq(token.balanceOf(alice), 9e18);
        assertEq(token.balanceOf(bob), 1e18);
    }

    function testTransferInsufficientFunds() public {
        token.mint(alice, 1e19);
        vm.prank(alice);
        vm.expectRevert("insufficient balance");
        token.transfer(bob, 2e19);
    }

    function testApprove() public {
        vm.prank(alice);
        vm.expectEmit(true, true, false, true);
        emit Approval(alice, bob, 1e18);
        token.approve(bob, 1e18);
        assertEq(token.allowance(alice, bob), 1e18);
    }

    function testTransferFrom() public {
        token.mint(alice, 1e19);
        vm.prank(alice);
        token.approve(bob, 3e18);
        vm.prank(bob);
        vm.expectEmit(true, true, false, true);
        emit Transfer(alice, charlie, 1e18);
        token.transferFrom(alice, charlie, 1e18);
        assertEq(token.balanceOf(alice), 9e18);
        assertEq(token.allowance(alice, bob), 2e18);
        assertEq(token.balanceOf(bob), 0);
        assertEq(token.balanceOf(charlie), 1e18);
    }

    function testTransferFromInsufficientAllowance() public {
        token.mint(alice, 1e19);
        vm.prank(alice);
        token.approve(bob, 3e18);
        vm.prank(bob);
        vm.expectRevert("insufficient allowance");
        token.transferFrom(alice, charlie, 4e18);
    }
}
