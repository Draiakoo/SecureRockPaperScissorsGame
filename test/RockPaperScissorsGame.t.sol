// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {RockPaperScissorsGame} from "../src/RockPaperScissorsGame.sol";
import {CoinManager} from "../src/CoinManager.sol";
import {Test, console} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";

contract RockPaperScissorsGameTest is StdCheats, Test{

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

    modifier DepositAmount(uint256 amountPlayer1, uint256 amountPlayer2){
        vm.prank(player1);
        gameContract.deposit{value: amountPlayer1}();
        vm.prank(player2);
        gameContract.deposit{value: amountPlayer2}();
        _;
    }


    /////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////
    //////////////////////////////////        Test createLobby function        //////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////

    function testcreateLobbyNotEnoughBalance() public {
        vm.startPrank(player1);
        vm.expectRevert(CoinManager.NotEnoughBalance.selector);
        gameContract.createLobby(1000 ether, 10 days, player2);
        vm.stopPrank();
    }

    function testcreateLobbyGameTooShort() public DepositAmount(20 ether, 20 ether){
        vm.startPrank(player1);
        vm.expectRevert(RockPaperScissorsGame.GameTooShort.selector);
        gameContract.createLobby(20 ether, 60 seconds, player2);
        vm.stopPrank();
    }

    function testcreateLobbyReservedSpot() public DepositAmount(20 ether, 20 ether){
        uint256 amountToBet = 20 ether;
        uint256 gameDuration = 2 days;
        uint256 currentTime = block.timestamp;
        vm.startPrank(player1);
        gameContract.createLobby(amountToBet, gameDuration, player2);
        vm.stopPrank();
        RockPaperScissorsGame.GameLobby memory gameStats = gameContract.gameInformation(0);
        assertEq(gameStats.player1, player1);
        assertEq(gameStats.player2, player2);
        assertEq(gameStats.betAmount, amountToBet);
        assert(gameStats.gameState == RockPaperScissorsGame.GameState.LookingForOpponent);
        assertEq(gameStats.deadline, currentTime + gameDuration);
    }

    function testcreateLobbyOpenSpot() public DepositAmount(20 ether, 20 ether){
        uint256 amountToBet = 20 ether;
        uint256 gameDuration = 2 days;
        uint256 currentTime = block.timestamp;
        vm.startPrank(player1);
        gameContract.createLobby(amountToBet, gameDuration, address(0));
        vm.stopPrank();
        RockPaperScissorsGame.GameLobby memory gameStats = gameContract.gameInformation(0);
        assertEq(gameStats.player1, player1);
        assertEq(gameStats.player2, address(0));
        assertEq(gameStats.betAmount, amountToBet);
        assert(gameStats.gameState == RockPaperScissorsGame.GameState.LookingForOpponent);
        assertEq(gameStats.deadline, currentTime + gameDuration);
    }

    /////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////        Test joinGameLobby function        /////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////

    modifier Player1CreateGame(bool reservedSpot){
        if (reservedSpot){
            vm.prank(player1);
            gameContract.createLobby(20 ether, 10 days, player2);
        } else {
            vm.prank(player1);
            gameContract.createLobby(20 ether, 10 days, address(0));
        }
        _;
    }

    function testJoinGameLobbyNotWaitingForOpponent() public {
        vm.prank(player2);
        vm.expectRevert(RockPaperScissorsGame.WrongGameState.selector);
        gameContract.joinGameLobby(0);
    }

    function testJoinGameLobbyNotEnoughBalance() public DepositAmount(20 ether, 1 ether) Player1CreateGame(true){
        vm.prank(player2);
        vm.expectRevert(CoinManager.NotEnoughBalance.selector);
        gameContract.joinGameLobby(0);
    }

    function testJoinGameLobbyExpiredGame() public DepositAmount(20 ether, 20 ether) Player1CreateGame(true){
        skip(20 days);
        vm.prank(player2);
        vm.expectRevert(RockPaperScissorsGame.GameExpired.selector);
        gameContract.joinGameLobby(0);
    }

    function testJoinGameLobbyReservedLobbyNotAuthorized() public DepositAmount(20 ether, 20 ether) Player1CreateGame(true){
        vm.deal(unauthorizedPlayer, 100 ether);
        vm.startPrank(unauthorizedPlayer);
        gameContract.deposit{value: 20 ether}();
        vm.expectRevert(RockPaperScissorsGame.GameSpotReserved.selector);
        gameContract.joinGameLobby(0);
        vm.stopPrank();
    }
    
    function testJoinGameLobbyReservedLobbyAuthorized() public DepositAmount(20 ether, 20 ether) Player1CreateGame(true){
        vm.prank(player2);
        gameContract.joinGameLobby(0);
        RockPaperScissorsGame.GameLobby memory gameStats = gameContract.gameInformation(0);
        assertEq(gameStats.player1, player1);
        assertEq(gameStats.player2, player2);
        assert(gameStats.gameState == RockPaperScissorsGame.GameState.WaitingForSubmits);
    }

    function testJoinGameLobbyNotReservedLobby() public DepositAmount(20 ether, 20 ether) Player1CreateGame(false){
        vm.deal(unauthorizedPlayer, 100 ether);
        vm.startPrank(unauthorizedPlayer);
        gameContract.deposit{value: 20 ether}();
        gameContract.joinGameLobby(0);
        vm.stopPrank();
        RockPaperScissorsGame.GameLobby memory gameStats = gameContract.gameInformation(0);
        assertEq(gameStats.player1, player1);
        assertEq(gameStats.player2, unauthorizedPlayer);
        assert(gameStats.gameState == RockPaperScissorsGame.GameState.WaitingForSubmits);
    }

    /////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////
    ///////////////////////////////////        Test submitHash function        //////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////

    modifier CreateAndFillGame(){
        vm.startPrank(player1);
        gameContract.deposit{value: 20 ether}();
        gameContract.createLobby(20 ether, 10 days, player2);
        vm.stopPrank();
        vm.startPrank(player2);
        gameContract.deposit{value: 20 ether}();
        gameContract.joinGameLobby(0);
        vm.stopPrank();
        _;
    }

    function testSubmitHashLobbyNotWaitingForSubmit() public {
        bytes32 hashToSubmit = keccak256(abi.encodePacked("Rock", "secretPassword"));
        vm.prank(player1);
        vm.expectRevert(RockPaperScissorsGame.WrongGameState.selector);
        gameContract.submitHash(0, hashToSubmit);
    }

    function testSubmitHashExpiredGame() public CreateAndFillGame{
        skip(20 days);
        bytes32 hashToSubmit = keccak256(abi.encodePacked("Rock", "secretPassword"));
        vm.prank(player1);
        vm.expectRevert(RockPaperScissorsGame.GameExpired.selector);
        gameContract.submitHash(0, hashToSubmit);
    }

    function testSubmitHashNotAPlayer() public CreateAndFillGame{
        bytes32 hashToSubmit = keccak256(abi.encodePacked("Rock", "secretPassword"));
        vm.prank(unauthorizedPlayer);
        vm.expectRevert(RockPaperScissorsGame.NotGamePlayer.selector);
        gameContract.submitHash(0, hashToSubmit);
    }

    function testSubmitHashFirstPlayerNotSecond() public CreateAndFillGame{
        bytes32 hashToSubmit = keccak256(abi.encodePacked("Rock", "secretPassword"));
        vm.prank(player1);
        gameContract.submitHash(0, hashToSubmit);
        RockPaperScissorsGame.GameLobby memory gameStats = gameContract.gameInformation(0);
        assertEq(gameStats.player1HashSubmit, hashToSubmit);
        assertEq(gameStats.player2HashSubmit, bytes32(0));
        assert(gameStats.gameState == RockPaperScissorsGame.GameState.WaitingForSubmits);
    }

    function testSubmitHashSecondPlayerNotFirst() public CreateAndFillGame{
        bytes32 hashToSubmit = keccak256(abi.encodePacked("Rock", "secretPassword"));
        vm.prank(player2);
        gameContract.submitHash(0, hashToSubmit);
        RockPaperScissorsGame.GameLobby memory gameStats = gameContract.gameInformation(0);
        assertEq(gameStats.player1HashSubmit, bytes32(0));
        assertEq(gameStats.player2HashSubmit, hashToSubmit);
        assert(gameStats.gameState == RockPaperScissorsGame.GameState.WaitingForSubmits);
    }
    
    function testSubmitHashFirstPlayerAndSecond() public CreateAndFillGame{
        bytes32 hashToSubmit1 = keccak256(abi.encodePacked("Rock", "secretPassword"));
        bytes32 hashToSubmit2 = keccak256(abi.encodePacked("Paper", "secretPassword"));
        vm.prank(player1);
        gameContract.submitHash(0, hashToSubmit1);
        vm.prank(player2);
        gameContract.submitHash(0, hashToSubmit2);
        RockPaperScissorsGame.GameLobby memory gameStats = gameContract.gameInformation(0);
        assertEq(gameStats.player1HashSubmit, hashToSubmit1);
        assertEq(gameStats.player2HashSubmit, hashToSubmit2);
        assert(gameStats.gameState == RockPaperScissorsGame.GameState.WaitingForChoiceDecryption);
    }
    
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////
    //////////////////////////////////        Test submitChoice function        /////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////

    function testSubmitChoiceLobbyNotWaitingForSubmit() public {}

    function testSubmitChoiceExpiredGame() public {}

    function testSubmitChoiceInvalidChoice() public {}

    function testSubmitChoiceNotAPlayer() public {}

    function testSubmitChoiceSubmitedHashNotMatching() public {}

    function testSubmitChoiceFirstPlayerNotSecond() public {}

    function testSubmitChoiceSecondPlayerNotFirst() public {}

    function testSubmitChoiceFirstPlayerAndSecond() public {}
}