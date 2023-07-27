// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {RockPaperScissorsGame} from "../src/RockPaperScissorsGame.sol";
import {CoinManager} from "../src/CoinManager.sol";
import {Test, console} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import "forge-std/console.sol";

contract ContractNotReceiver {
    fallback() external{}
}

contract RockPaperScissorsGameTest is StdCheats, Test {
    RockPaperScissorsGame gameContract;

    address public deployer = makeAddr("deployer");
    address public player1 = makeAddr("player 1");
    address public player2 = makeAddr("player 2");
    address public unauthorizedPlayer = makeAddr("Unauthorized player");

    function setUp() external {
        vm.deal(player1, 100 ether);
        vm.deal(player2, 100 ether);
        vm.prank(deployer);
        gameContract = new RockPaperScissorsGame();
    }

    /////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////        Test deposit function        ////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////

    function testDepositZeroValue() public {
        vm.prank(player1);
        vm.expectRevert(CoinManager.AmountCanNotBeZero.selector);
        gameContract.deposit{value: 0}();
    }

    function testDepositSuccess() public {
        uint256 balanceBefore = gameContract.balanceOf(player1);
        vm.prank(player1);
        gameContract.deposit{value: 10 ether}();
        uint256 balanceAfter = gameContract.balanceOf(player1);
        assertEq(balanceBefore + 10 ether, balanceAfter);
    }

    /////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////        Test withdraw function        ///////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////

    function testWithdrawNotEnoughBalance() public {
        vm.startPrank(player1);
        gameContract.deposit{value: 10 ether}();
        vm.expectRevert(CoinManager.NotEnoughBalance.selector);
        gameContract.withdraw(20 ether);
        vm.stopPrank();
    }

    function testWithdrawTransactionFailed() public {
        ContractNotReceiver notReceiver = new ContractNotReceiver();
        vm.deal(address(notReceiver), 10 ether);
        vm.startPrank(address(notReceiver));
        gameContract.deposit{value: 10 ether}();
        vm.expectRevert(CoinManager.TransactionFailed.selector);
        gameContract.withdraw(10 ether);
        vm.stopPrank();
    }

    function testWithdrawSuccess() public {
        vm.startPrank(player1);
        gameContract.deposit{value: 10 ether}();
        uint256 balanceBefore = gameContract.balanceOf(player1);
        gameContract.withdraw(10 ether);
        uint256 balanceAfter = gameContract.balanceOf(player1);
        vm.stopPrank();
        assertEq(balanceBefore - 10 ether, balanceAfter);
    }

    /////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////
    ///////////////////////////////////        Test payBetEntry function        /////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////

    function testPayBetEntry() public {
        vm.startPrank(player1);
        gameContract.deposit{value: 10 ether}();
        uint256 balanceBefore = gameContract.balanceOf(player1);
        gameContract.createLobby(10 ether, 10 days, player2);
        uint256 balanceAfter = gameContract.balanceOf(player1);
        vm.stopPrank();
        assertEq(balanceBefore - 10 ether, balanceAfter);
    }

    /////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////
    //////////////////////////////////        Test payBetToWinner function        ///////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////

    function testPayBetToWinner() public {
        vm.startPrank(player1);
        gameContract.deposit{value: 10 ether}();
        gameContract.createLobby(10 ether, 10 days, player2);
        uint256 balanceBefore = gameContract.balanceOf(player1);
        gameContract.cancelGameLobby(0);
        uint256 balanceAfter = gameContract.balanceOf(player1);
        vm.stopPrank();
        assertEq(balanceBefore + 10 ether, balanceAfter);
    }

    /////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////
    ///////////////////////////////////        Test balanceOf function        ///////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////

    function testBalanceOf() public {
        vm.startPrank(player1);
        gameContract.deposit{value: 10 ether}();
        uint256 balance = gameContract.balanceOf(player1);
        vm.stopPrank();
        assertEq(balance, 10 ether);
    }
}