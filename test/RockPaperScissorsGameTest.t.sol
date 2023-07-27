// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {RockPaperScissorsGame} from "../src/RockPaperScissorsGame.sol";
import {CoinManager} from "../src/CoinManager.sol";
import {Test, console} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import "forge-std/console.sol";

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

    modifier DepositAmount(uint256 amountPlayer1, uint256 amountPlayer2) {
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

    function testcreateLobbyGameTooShort() public DepositAmount(20 ether, 20 ether) {
        vm.startPrank(player1);
        vm.expectRevert(RockPaperScissorsGame.GameTooShort.selector);
        gameContract.createLobby(20 ether, 60 seconds, player2);
        vm.stopPrank();
    }

    function testcreateLobbyReservedSpot() public DepositAmount(20 ether, 20 ether) {
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

    function testcreateLobbyOpenSpot() public DepositAmount(20 ether, 20 ether) {
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

    modifier Player1CreateGame(bool reservedSpot) {
        if (reservedSpot) {
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

    function testJoinGameLobbyNotEnoughBalance() public DepositAmount(20 ether, 1 ether) Player1CreateGame(true) {
        vm.prank(player2);
        vm.expectRevert(CoinManager.NotEnoughBalance.selector);
        gameContract.joinGameLobby(0);
    }

    function testJoinGameLobbyExpiredGame() public DepositAmount(20 ether, 20 ether) Player1CreateGame(true) {
        skip(20 days);
        vm.prank(player2);
        vm.expectRevert(RockPaperScissorsGame.GameExpired.selector);
        gameContract.joinGameLobby(0);
    }

    function testJoinGameLobbyCreatorCanNotJoin() public DepositAmount(40 ether, 20 ether) Player1CreateGame(true) {
        vm.prank(player1);
        vm.expectRevert(RockPaperScissorsGame.YouCanNotJoinAGameYouCreated.selector);
        gameContract.joinGameLobby(0);
    }

    function testJoinGameLobbyReservedLobbyNotAuthorized()
        public
        DepositAmount(20 ether, 20 ether)
        Player1CreateGame(true)
    {
        vm.deal(unauthorizedPlayer, 100 ether);
        vm.startPrank(unauthorizedPlayer);
        gameContract.deposit{value: 20 ether}();
        vm.expectRevert(RockPaperScissorsGame.GameSpotReserved.selector);
        gameContract.joinGameLobby(0);
        vm.stopPrank();
    }

    function testJoinGameLobbyReservedLobbyAuthorized()
        public
        DepositAmount(20 ether, 20 ether)
        Player1CreateGame(true)
    {
        vm.prank(player2);
        gameContract.joinGameLobby(0);
        RockPaperScissorsGame.GameLobby memory gameStats = gameContract.gameInformation(0);
        assertEq(gameStats.player1, player1);
        assertEq(gameStats.player2, player2);
        assert(gameStats.gameState == RockPaperScissorsGame.GameState.WaitingForSubmits);
    }

    function testJoinGameLobbyNotReservedLobby() public DepositAmount(20 ether, 20 ether) Player1CreateGame(false) {
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

    modifier CreateAndFillGame() {
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

    function testSubmitHashExpiredGame() public CreateAndFillGame {
        skip(20 days);
        bytes32 hashToSubmit = keccak256(abi.encodePacked("Rock", "secretPassword"));
        vm.prank(player1);
        vm.expectRevert(RockPaperScissorsGame.GameExpired.selector);
        gameContract.submitHash(0, hashToSubmit);
    }

    function testSubmitHashNotAPlayer() public CreateAndFillGame {
        bytes32 hashToSubmit = keccak256(abi.encodePacked("Rock", "secretPassword"));
        vm.prank(unauthorizedPlayer);
        vm.expectRevert(RockPaperScissorsGame.NotGamePlayer.selector);
        gameContract.submitHash(0, hashToSubmit);
    }

    function testSubmitHashFirstPlayerNotSecond() public CreateAndFillGame {
        bytes32 hashToSubmit = keccak256(abi.encodePacked("Rock", "secretPassword"));
        vm.prank(player1);
        gameContract.submitHash(0, hashToSubmit);
        RockPaperScissorsGame.GameLobby memory gameStats = gameContract.gameInformation(0);
        assertEq(gameStats.player1HashSubmit, hashToSubmit);
        assertEq(gameStats.player2HashSubmit, bytes32(0));
        assert(gameStats.gameState == RockPaperScissorsGame.GameState.WaitingForSubmits);
    }

    function testSubmitHashSecondPlayerNotFirst() public CreateAndFillGame {
        bytes32 hashToSubmit = keccak256(abi.encodePacked("Rock", "secretPassword"));
        vm.prank(player2);
        gameContract.submitHash(0, hashToSubmit);
        RockPaperScissorsGame.GameLobby memory gameStats = gameContract.gameInformation(0);
        assertEq(gameStats.player1HashSubmit, bytes32(0));
        assertEq(gameStats.player2HashSubmit, hashToSubmit);
        assert(gameStats.gameState == RockPaperScissorsGame.GameState.WaitingForSubmits);
    }

    function testSubmitHashFirstPlayerAndSecond() public CreateAndFillGame {
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

    function testSubmitHashSecondPlayerAndFirst() public CreateAndFillGame {
        bytes32 hashToSubmit1 = keccak256(abi.encodePacked("Rock", "secretPassword"));
        bytes32 hashToSubmit2 = keccak256(abi.encodePacked("Paper", "secretPassword"));
        vm.prank(player2);
        gameContract.submitHash(0, hashToSubmit2);
        vm.prank(player1);
        gameContract.submitHash(0, hashToSubmit1);
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

    modifier CreateGameFillAndSubmitHash(bytes32 hashPlayer1, bytes32 hashPlayer2) {
        vm.startPrank(player1);
        gameContract.deposit{value: 20 ether}();
        gameContract.createLobby(20 ether, 10 days, player2);
        vm.stopPrank();
        vm.startPrank(player2);
        gameContract.deposit{value: 20 ether}();
        gameContract.joinGameLobby(0);
        vm.stopPrank();
        vm.prank(player1);
        gameContract.submitHash(0, hashPlayer1);
        vm.prank(player2);
        gameContract.submitHash(0, hashPlayer2);
        _;
    }

    function testSubmitChoiceLobbyNotWaitingForSubmit() public {
        vm.prank(player1);
        vm.expectRevert(RockPaperScissorsGame.WrongGameState.selector);
        gameContract.submitChoice(0, "Rock", "secretPassword");
    }

    function testSubmitChoiceExpiredGame()
        public
        CreateGameFillAndSubmitHash(
            keccak256(abi.encodePacked("Rock", "SecretPassword1")),
            keccak256(abi.encodePacked("Paper", "SecretPassword2"))
        )
    {
        skip(20 days);
        vm.prank(player1);
        vm.expectRevert(RockPaperScissorsGame.GameExpired.selector);
        gameContract.submitChoice(0, "Rock", "SecretPassword1");
    }

    function testSubmitChoiceInvalidChoice()
        public
        CreateGameFillAndSubmitHash(
            keccak256(abi.encodePacked("Rocko", "SecretPassword1")),
            keccak256(abi.encodePacked("Paper", "SecretPassword2"))
        )
    {
        vm.prank(player1);
        vm.expectRevert(RockPaperScissorsGame.InvalidChoice.selector);
        gameContract.submitChoice(0, "Rocko", "SecretPassword1");
    }

    function testSubmitChoiceNotAPlayer()
        public
        CreateGameFillAndSubmitHash(
            keccak256(abi.encodePacked("Rock", "SecretPassword1")),
            keccak256(abi.encodePacked("Paper", "SecretPassword2"))
        )
    {
        vm.prank(unauthorizedPlayer);
        vm.expectRevert(RockPaperScissorsGame.NotGamePlayer.selector);
        gameContract.submitChoice(0, "Rock", "SecretPassword1");
    }

    function testSubmitChoiceSubmitedHashNotMatchingPlayer1()
        public
        CreateGameFillAndSubmitHash(
            keccak256(abi.encodePacked("Rock", "SecretPassword1")),
            keccak256(abi.encodePacked("Paper", "SecretPassword2"))
        )
    {
        vm.prank(player1);
        vm.expectRevert(RockPaperScissorsGame.ChoiceAndPasswordNotMatching.selector);
        gameContract.submitChoice(0, "Rock", "WrongPassword");
    }

    function testSubmitChoiceSubmitedHashNotMatchingPlayer2()
        public
        CreateGameFillAndSubmitHash(
            keccak256(abi.encodePacked("Rock", "SecretPassword1")),
            keccak256(abi.encodePacked("Paper", "SecretPassword2"))
        )
    {
        vm.prank(player2);
        vm.expectRevert(RockPaperScissorsGame.ChoiceAndPasswordNotMatching.selector);
        gameContract.submitChoice(0, "Paper", "WrongPassword");
    }

    function testSubmitChoiceFirstPlayerNotSecond()
        public
        CreateGameFillAndSubmitHash(
            keccak256(abi.encodePacked("Rock", "SecretPassword1")),
            keccak256(abi.encodePacked("Paper", "SecretPassword2"))
        )
    {
        vm.prank(player1);
        gameContract.submitChoice(0, "Rock", "SecretPassword1");
        RockPaperScissorsGame.GameLobby memory gameStats = gameContract.gameInformation(0);
        assert(uint8(gameStats.player1DecryptedChoice) == uint8(RockPaperScissorsGame.Choice.Rock));
        assert(uint8(gameStats.player2DecryptedChoice) == uint8(RockPaperScissorsGame.Choice.Encrypted));
        assert(gameStats.gameState == RockPaperScissorsGame.GameState.WaitingForChoiceDecryption);
    }

    function testSubmitChoiceSecondPlayerNotFirst()
        public
        CreateGameFillAndSubmitHash(
            keccak256(abi.encodePacked("Rock", "SecretPassword1")),
            keccak256(abi.encodePacked("Paper", "SecretPassword2"))
        )
    {
        vm.prank(player2);
        gameContract.submitChoice(0, "Paper", "SecretPassword2");
        RockPaperScissorsGame.GameLobby memory gameStats = gameContract.gameInformation(0);
        assert(uint8(gameStats.player1DecryptedChoice) == uint8(RockPaperScissorsGame.Choice.Encrypted));
        assert(uint8(gameStats.player2DecryptedChoice) == uint8(RockPaperScissorsGame.Choice.Paper));
        assert(gameStats.gameState == RockPaperScissorsGame.GameState.WaitingForChoiceDecryption);
    }

    function testSubmitChoiceFirstPlayerAndSecond()
        public
        CreateGameFillAndSubmitHash(
            keccak256(abi.encodePacked("Rock", "SecretPassword1")),
            keccak256(abi.encodePacked("Paper", "SecretPassword2"))
        )
    {
        vm.prank(player1);
        gameContract.submitChoice(0, "Rock", "SecretPassword1");
        vm.prank(player2);
        gameContract.submitChoice(0, "Paper", "SecretPassword2");
        RockPaperScissorsGame.GameLobby memory gameStats = gameContract.gameInformation(0);
        assert(uint8(gameStats.player1DecryptedChoice) == uint8(RockPaperScissorsGame.Choice.Rock));
        assert(uint8(gameStats.player2DecryptedChoice) == uint8(RockPaperScissorsGame.Choice.Paper));
        assert(gameStats.gameState == RockPaperScissorsGame.GameState.Finalized);
    }

    function testSubmitChoiceSecondPlayerAndFirst()
        public
        CreateGameFillAndSubmitHash(
            keccak256(abi.encodePacked("Rock", "SecretPassword1")),
            keccak256(abi.encodePacked("Paper", "SecretPassword2"))
        )
    {
        vm.prank(player2);
        gameContract.submitChoice(0, "Paper", "SecretPassword2");
        vm.prank(player1);
        gameContract.submitChoice(0, "Rock", "SecretPassword1");
        RockPaperScissorsGame.GameLobby memory gameStats = gameContract.gameInformation(0);
        assert(uint8(gameStats.player1DecryptedChoice) == uint8(RockPaperScissorsGame.Choice.Rock));
        assert(uint8(gameStats.player2DecryptedChoice) == uint8(RockPaperScissorsGame.Choice.Paper));
        assert(gameStats.gameState == RockPaperScissorsGame.GameState.Finalized);
    }

    /////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////        Test checkGameState function        ////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////

    function testCheckGameStateNotPlayer() public CreateAndFillGame {
        vm.prank(unauthorizedPlayer);
        vm.expectRevert(RockPaperScissorsGame.NotGamePlayer.selector);
        gameContract.checkGameState(0);
    }

    function testCheckGameStateDeadlineNotReached()
        public
        CreateGameFillAndSubmitHash(
            keccak256(abi.encodePacked("Rock", "SecretPassword1")),
            keccak256(abi.encodePacked("Paper", "SecretPassword2"))
        )
    {
        vm.startPrank(player1);
        gameContract.submitChoice(0, "Rock", "SecretPassword1");
        vm.expectRevert(RockPaperScissorsGame.DeadlineNotReached.selector);
        gameContract.checkGameState(0);
        vm.stopPrank();
    }

    function testCheckGameStateDeadlineReached()
        public
        CreateGameFillAndSubmitHash(
            keccak256(abi.encodePacked("Rock", "SecretPassword1")),
            keccak256(abi.encodePacked("Paper", "SecretPassword2"))
        )
    {
        vm.startPrank(player1);
        gameContract.submitChoice(0, "Rock", "SecretPassword1");
        skip(20 days);
        gameContract.checkGameState(0);
        vm.stopPrank();
        RockPaperScissorsGame.GameLobby memory gameStats = gameContract.gameInformation(0);
        assert(gameStats.gameState == RockPaperScissorsGame.GameState.Finalized);
    }

    /////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////
    //////////////////////////////////        Test checkResult function        //////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////

    function testCheckResultNoPlayersSubmitedHash() public CreateAndFillGame {
        uint256 balancePlayer1Before = gameContract.balanceOf(player1);
        uint256 balancePlayer2Before = gameContract.balanceOf(player2);
        uint256 betAmount = gameContract.gameInformation(0).betAmount;
        skip(20 days);
        vm.prank(player1);
        gameContract.checkGameState(0);
        RockPaperScissorsGame.GameState gameState = gameContract.gameInformation(0).gameState;
        uint256 balancePlayer1After = gameContract.balanceOf(player1);
        uint256 balancePlayer2After = gameContract.balanceOf(player2);
        assertEq(balancePlayer1Before + betAmount, balancePlayer1After);
        assertEq(balancePlayer2Before + betAmount, balancePlayer2After);
        assert(gameState == RockPaperScissorsGame.GameState.Finalized);
    }

    function testCheckResultPlayer1SubmitedHashPlayer2No() public CreateAndFillGame {
        uint256 balancePlayer1Before = gameContract.balanceOf(player1);
        uint256 betAmount = gameContract.gameInformation(0).betAmount;
        vm.startPrank(player1);
        gameContract.submitHash(0, keccak256(abi.encodePacked("Rock", "secretPassword1")));
        skip(20 days);
        gameContract.checkGameState(0);
        vm.stopPrank();
        RockPaperScissorsGame.GameState gameState = gameContract.gameInformation(0).gameState;
        uint256 balancePlayer1After = gameContract.balanceOf(player1);
        assertEq(balancePlayer1Before + 2 * betAmount, balancePlayer1After);
        assert(gameState == RockPaperScissorsGame.GameState.Finalized);
    }

    function testCheckResultPlayer2SubmitedHashPlayer1No() public CreateAndFillGame {
        uint256 balancePlayer2Before = gameContract.balanceOf(player2);
        uint256 betAmount = gameContract.gameInformation(0).betAmount;
        vm.startPrank(player2);
        gameContract.submitHash(0, keccak256(abi.encodePacked("Rock", "secretPassword2")));
        skip(20 days);
        gameContract.checkGameState(0);
        vm.stopPrank();
        RockPaperScissorsGame.GameState gameState = gameContract.gameInformation(0).gameState;
        uint256 balancePlayer2After = gameContract.balanceOf(player2);
        assertEq(balancePlayer2Before + 2 * betAmount, balancePlayer2After);
        assert(gameState == RockPaperScissorsGame.GameState.Finalized);
    }

    function testCheckResultNoPlayersSubmitedChoice()
        public
        CreateGameFillAndSubmitHash(
            keccak256(abi.encodePacked("Rock", "SecretPassword1")),
            keccak256(abi.encodePacked("Paper", "SecretPassword2"))
        )
    {
        uint256 balancePlayer1Before = gameContract.balanceOf(player1);
        uint256 balancePlayer2Before = gameContract.balanceOf(player2);
        uint256 betAmount = gameContract.gameInformation(0).betAmount;
        skip(20 days);
        vm.prank(player1);
        gameContract.checkGameState(0);
        RockPaperScissorsGame.GameState gameState = gameContract.gameInformation(0).gameState;
        uint256 balancePlayer1After = gameContract.balanceOf(player1);
        uint256 balancePlayer2After = gameContract.balanceOf(player2);
        assertEq(balancePlayer1Before + betAmount, balancePlayer1After);
        assertEq(balancePlayer2Before + betAmount, balancePlayer2After);
        assert(gameState == RockPaperScissorsGame.GameState.Finalized);
    }

    function testCheckResultPlayer1SubmitedChoicePlayer2No()
        public
        CreateGameFillAndSubmitHash(
            keccak256(abi.encodePacked("Rock", "SecretPassword1")),
            keccak256(abi.encodePacked("Paper", "SecretPassword2"))
        )
    {
        uint256 balancePlayer1Before = gameContract.balanceOf(player1);
        uint256 betAmount = gameContract.gameInformation(0).betAmount;
        vm.startPrank(player1);
        gameContract.submitChoice(0, "Rock", "SecretPassword1");
        skip(20 days);
        gameContract.checkGameState(0);
        vm.stopPrank();
        RockPaperScissorsGame.GameState gameState = gameContract.gameInformation(0).gameState;
        uint256 balancePlayer1After = gameContract.balanceOf(player1);
        assertEq(balancePlayer1Before + 2 * betAmount, balancePlayer1After);
        assert(gameState == RockPaperScissorsGame.GameState.Finalized);
    }

    function testCheckResultPlayer2SubmitedChoicePlayer1No()
        public
        CreateGameFillAndSubmitHash(
            keccak256(abi.encodePacked("Rock", "SecretPassword1")),
            keccak256(abi.encodePacked("Paper", "SecretPassword2"))
        )
    {
        uint256 balancePlayer2Before = gameContract.balanceOf(player2);
        uint256 betAmount = gameContract.gameInformation(0).betAmount;
        vm.startPrank(player2);
        gameContract.submitChoice(0, "Paper", "SecretPassword2");
        skip(20 days);
        gameContract.checkGameState(0);
        vm.stopPrank();
        RockPaperScissorsGame.GameState gameState = gameContract.gameInformation(0).gameState;
        uint256 balancePlayer2After = gameContract.balanceOf(player2);
        assertEq(balancePlayer2Before + 2 * betAmount, balancePlayer2After);
        assert(gameState == RockPaperScissorsGame.GameState.Finalized);
    }

    /////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////
    //////////////////////////////////        Test gameLogic function        ////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////

    function testGameLogicPlayer1RockPlayer2Rock()
        public
        CreateGameFillAndSubmitHash(
            keccak256(abi.encodePacked("Rock", "SecretPassword1")),
            keccak256(abi.encodePacked("Rock", "SecretPassword2"))
        )
    {
        uint256 balancePlayer1Before = gameContract.balanceOf(player1);
        uint256 balancePlayer2Before = gameContract.balanceOf(player2);
        uint256 betAmount = gameContract.gameInformation(0).betAmount;
        vm.prank(player1);
        gameContract.submitChoice(0, "Rock", "SecretPassword1");
        vm.prank(player2);
        gameContract.submitChoice(0, "Rock", "SecretPassword2");
        RockPaperScissorsGame.GameState gameState = gameContract.gameInformation(0).gameState;
        uint256 balancePlayer1After = gameContract.balanceOf(player1);
        uint256 balancePlayer2After = gameContract.balanceOf(player2);
        assertEq(balancePlayer1Before + betAmount, balancePlayer1After);
        assertEq(balancePlayer2Before + betAmount, balancePlayer2After);
        assert(gameState == RockPaperScissorsGame.GameState.Finalized);
    }

    function testGameLogicPlayer1RockPlayer2Paper()
        public
        CreateGameFillAndSubmitHash(
            keccak256(abi.encodePacked("Rock", "SecretPassword1")),
            keccak256(abi.encodePacked("Paper", "SecretPassword2"))
        )
    {
        uint256 balancePlayer2Before = gameContract.balanceOf(player2);
        uint256 betAmount = gameContract.gameInformation(0).betAmount;
        vm.prank(player1);
        gameContract.submitChoice(0, "Rock", "SecretPassword1");
        vm.prank(player2);
        gameContract.submitChoice(0, "Paper", "SecretPassword2");
        RockPaperScissorsGame.GameState gameState = gameContract.gameInformation(0).gameState;
        uint256 balancePlayer2After = gameContract.balanceOf(player2);
        assertEq(balancePlayer2Before + 2 * betAmount, balancePlayer2After);
        assert(gameState == RockPaperScissorsGame.GameState.Finalized);
    }

    function testGameLogicPlayer1RockPlayer2Scissors()
        public
        CreateGameFillAndSubmitHash(
            keccak256(abi.encodePacked("Rock", "SecretPassword1")),
            keccak256(abi.encodePacked("Scissors", "SecretPassword2"))
        )
    {
        uint256 balancePlayer1Before = gameContract.balanceOf(player1);
        uint256 betAmount = gameContract.gameInformation(0).betAmount;
        vm.prank(player1);
        gameContract.submitChoice(0, "Rock", "SecretPassword1");
        vm.prank(player2);
        gameContract.submitChoice(0, "Scissors", "SecretPassword2");
        RockPaperScissorsGame.GameState gameState = gameContract.gameInformation(0).gameState;
        uint256 balancePlayer1After = gameContract.balanceOf(player1);
        assertEq(balancePlayer1Before + 2 * betAmount, balancePlayer1After);
        assert(gameState == RockPaperScissorsGame.GameState.Finalized);
    }

    function testGameLogicPlayer1PaperPlayer2Rock()
        public
        CreateGameFillAndSubmitHash(
            keccak256(abi.encodePacked("Paper", "SecretPassword1")),
            keccak256(abi.encodePacked("Rock", "SecretPassword2"))
        )
    {
        uint256 balancePlayer1Before = gameContract.balanceOf(player1);
        uint256 betAmount = gameContract.gameInformation(0).betAmount;
        vm.prank(player1);
        gameContract.submitChoice(0, "Paper", "SecretPassword1");
        vm.prank(player2);
        gameContract.submitChoice(0, "Rock", "SecretPassword2");
        RockPaperScissorsGame.GameState gameState = gameContract.gameInformation(0).gameState;
        uint256 balancePlayer1After = gameContract.balanceOf(player1);
        assertEq(balancePlayer1Before + 2 * betAmount, balancePlayer1After);
        assert(gameState == RockPaperScissorsGame.GameState.Finalized);
    }

    function testGameLogicPlayer1PaperPlayer2Paper()
        public
        CreateGameFillAndSubmitHash(
            keccak256(abi.encodePacked("Paper", "SecretPassword1")),
            keccak256(abi.encodePacked("Paper", "SecretPassword2"))
        )
    {
        uint256 balancePlayer1Before = gameContract.balanceOf(player1);
        uint256 balancePlayer2Before = gameContract.balanceOf(player2);
        uint256 betAmount = gameContract.gameInformation(0).betAmount;
        vm.prank(player1);
        gameContract.submitChoice(0, "Paper", "SecretPassword1");
        vm.prank(player2);
        gameContract.submitChoice(0, "Paper", "SecretPassword2");
        RockPaperScissorsGame.GameState gameState = gameContract.gameInformation(0).gameState;
        uint256 balancePlayer1After = gameContract.balanceOf(player1);
        uint256 balancePlayer2After = gameContract.balanceOf(player2);
        assertEq(balancePlayer1Before + betAmount, balancePlayer1After);
        assertEq(balancePlayer2Before + betAmount, balancePlayer2After);
        assert(gameState == RockPaperScissorsGame.GameState.Finalized);
    }

    function testGameLogicPlayer1PaperPlayer2Scissors()
        public
        CreateGameFillAndSubmitHash(
            keccak256(abi.encodePacked("Paper", "SecretPassword1")),
            keccak256(abi.encodePacked("Scissors", "SecretPassword2"))
        )
    {
        uint256 balancePlayer2Before = gameContract.balanceOf(player2);
        uint256 betAmount = gameContract.gameInformation(0).betAmount;
        vm.prank(player1);
        gameContract.submitChoice(0, "Paper", "SecretPassword1");
        vm.prank(player2);
        gameContract.submitChoice(0, "Scissors", "SecretPassword2");
        RockPaperScissorsGame.GameState gameState = gameContract.gameInformation(0).gameState;
        uint256 balancePlayer2After = gameContract.balanceOf(player2);
        assertEq(balancePlayer2Before + 2 * betAmount, balancePlayer2After);
        assert(gameState == RockPaperScissorsGame.GameState.Finalized);
    }

    function testGameLogicPlayer1ScissorsPlayer2Rock()
        public
        CreateGameFillAndSubmitHash(
            keccak256(abi.encodePacked("Scissors", "SecretPassword1")),
            keccak256(abi.encodePacked("Rock", "SecretPassword2"))
        )
    {
        uint256 balancePlayer2Before = gameContract.balanceOf(player2);
        uint256 betAmount = gameContract.gameInformation(0).betAmount;
        vm.prank(player1);
        gameContract.submitChoice(0, "Scissors", "SecretPassword1");
        vm.prank(player2);
        gameContract.submitChoice(0, "Rock", "SecretPassword2");
        RockPaperScissorsGame.GameState gameState = gameContract.gameInformation(0).gameState;
        uint256 balancePlayer2After = gameContract.balanceOf(player2);
        assertEq(balancePlayer2Before + 2 * betAmount, balancePlayer2After);
        assert(gameState == RockPaperScissorsGame.GameState.Finalized);
    }

    function testGameLogicPlayer1ScissorsPlayer2Paper()
        public
        CreateGameFillAndSubmitHash(
            keccak256(abi.encodePacked("Scissors", "SecretPassword1")),
            keccak256(abi.encodePacked("Paper", "SecretPassword2"))
        )
    {
        uint256 balancePlayer1Before = gameContract.balanceOf(player1);
        uint256 betAmount = gameContract.gameInformation(0).betAmount;
        vm.prank(player1);
        gameContract.submitChoice(0, "Scissors", "SecretPassword1");
        vm.prank(player2);
        gameContract.submitChoice(0, "Paper", "SecretPassword2");
        RockPaperScissorsGame.GameState gameState = gameContract.gameInformation(0).gameState;
        uint256 balancePlayer1After = gameContract.balanceOf(player1);
        assertEq(balancePlayer1Before + 2 * betAmount, balancePlayer1After);
        assert(gameState == RockPaperScissorsGame.GameState.Finalized);
    }

    function testGameLogicPlayer1ScissorsPlayer2Scissors()
        public
        CreateGameFillAndSubmitHash(
            keccak256(abi.encodePacked("Scissors", "SecretPassword1")),
            keccak256(abi.encodePacked("Scissors", "SecretPassword2"))
        )
    {
        uint256 balancePlayer1Before = gameContract.balanceOf(player1);
        uint256 balancePlayer2Before = gameContract.balanceOf(player2);
        uint256 betAmount = gameContract.gameInformation(0).betAmount;
        vm.prank(player1);
        gameContract.submitChoice(0, "Scissors", "SecretPassword1");
        vm.prank(player2);
        gameContract.submitChoice(0, "Scissors", "SecretPassword2");
        RockPaperScissorsGame.GameState gameState = gameContract.gameInformation(0).gameState;
        uint256 balancePlayer1After = gameContract.balanceOf(player1);
        uint256 balancePlayer2After = gameContract.balanceOf(player2);
        assertEq(balancePlayer1Before + betAmount, balancePlayer1After);
        assertEq(balancePlayer2Before + betAmount, balancePlayer2After);
        assert(gameState == RockPaperScissorsGame.GameState.Finalized);
    }

    /////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////
    ///////////////////////////////        Test cancelGameLobby function        /////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////

    function testCancelGameLobbyWrongState() public DepositAmount(20 ether, 20 ether) CreateAndFillGame{
        vm.prank(player1);
        vm.expectRevert(RockPaperScissorsGame.WrongGameState.selector);
        gameContract.cancelGameLobby(0);
    }

    function testCancelGameLobbyExpiredGame() public DepositAmount(20 ether, 20 ether) Player1CreateGame(false){
        skip(20 days);
        vm.prank(player1);
        vm.expectRevert(RockPaperScissorsGame.GameExpired.selector);
        gameContract.cancelGameLobby(0);
    }

    function testCancelGameLobbyNotCreator() public DepositAmount(20 ether, 20 ether) Player1CreateGame(false){
        vm.prank(player2);
        vm.expectRevert(RockPaperScissorsGame.NotGameCreator.selector);
        gameContract.cancelGameLobby(0);
    }

    function testCancelGameLobbySuccess() public DepositAmount(20 ether, 20 ether) Player1CreateGame(false){
        uint256 player1BalanceBefore = gameContract.balanceOf(player1);
        vm.prank(player1);
        gameContract.cancelGameLobby(0);
        RockPaperScissorsGame.GameLobby memory gameInfo = gameContract.gameInformation(0);
        uint256 player1BalanceAfter = gameContract.balanceOf(player1);
        assertEq(player1BalanceBefore + 20 ether, player1BalanceAfter);
        assertEq(gameInfo.player1, address(0));
        assertEq(gameInfo.player2, address(0));
        assertEq(gameInfo.betAmount, 0);
        assertEq(gameInfo.player1HashSubmit, bytes32(0x0));
        assertEq(gameInfo.player2HashSubmit, bytes32(0x0));
        assert(uint8(gameInfo.player1DecryptedChoice) == uint8(RockPaperScissorsGame.Choice.Encrypted));
        assert(uint8(gameInfo.player2DecryptedChoice) == uint8(RockPaperScissorsGame.Choice.Encrypted));
        assert(gameInfo.gameState == RockPaperScissorsGame.GameState.NotInitialized);
        assertEq(gameInfo.deadline, 0);
    }

    /////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////
    ///////////////////////////////        Test gameInformation function        /////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////

    function testGameInformation() public CreateAndFillGame{
        RockPaperScissorsGame.GameLobby memory gameInfo = gameContract.gameInformation(0);
        assertEq(gameInfo.player1, player1);
        assertEq(gameInfo.player2, player2);
        assertEq(gameInfo.betAmount, 20 ether);
        assertEq(gameInfo.player1HashSubmit, bytes32(0x0));
        assertEq(gameInfo.player2HashSubmit, bytes32(0x0));
        assert(uint8(gameInfo.player1DecryptedChoice) == uint8(RockPaperScissorsGame.Choice.Encrypted));
        assert(uint8(gameInfo.player2DecryptedChoice) == uint8(RockPaperScissorsGame.Choice.Encrypted));
        assert(gameInfo.gameState == RockPaperScissorsGame.GameState.WaitingForSubmits);
        assertEq(gameInfo.deadline, block.timestamp + 10 days);
    }   
}
