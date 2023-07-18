// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {CoinManager} from "./CoinManager.sol";

contract RockPaperScissorsGame is CoinManager {
    error WrongGameState();
    error GameExpired();
    error DeadlineNotReached();
    error NotGamePlayer();

    enum Choice {
        Encrypted,
        Rock,
        Paper,
        Scissors
    }

    enum GameState {
        NotInitialized,
        LookingForOpponent,
        WaitingForSubmits,
        WaitingForChoiceDecryption,
        Finalized
    }

    struct GameLobby {
        address player1;
        address player2;
        uint256 betAmount;
        bytes32 player1HashSubmit;
        bytes32 player2HashSubmit;
        Choice player1DecryptedChoice;
        Choice player2DecryptedChoice;
        GameState gameState;
        uint256 deadline;
    }

    mapping(uint256 gameId => GameLobby game) public games;

    uint256 public gameIdCounter;

    modifier GameLobbyWaitingForOpponent(uint256 _gameId) {
        if (games[_gameId].gameState != GameState.LookingForOpponent) {
            revert WrongGameState();
        }
        _;
    }

    modifier NotExpiredGame(uint256 _gameId) {
        if (games[_gameId].deadline < block.timestamp) {
            revert GameExpired();
        }
        _;
    }

    modifier GameLobbyWaitingForSubmit(uint256 _gameId) {
        if (games[_gameId].gameState != GameState.WaitingForSubmits) {
            revert WrongGameState();
        }
        _;
    }

    function createLobbyForEverybody(uint256 _betAmount, uint256 _gameDuration)
        external
        EnoughBalanceAvailable(msg.sender, _betAmount)
    {
        payBetEntry(msg.sender, _betAmount);
        GameLobby storage newGame = games[gameIdCounter];
        newGame.player1 = msg.sender;
        newGame.betAmount = _betAmount;
        newGame.gameState = GameState.LookingForOpponent;
        newGame.deadline = block.timestamp + _gameDuration;
        unchecked {
            gameIdCounter++;
        }
    }

    function createLobbyForAPeer(uint256 _betAmount, address _secondPlayer, uint256 _gameDuration) external {
        payBetEntry(msg.sender, _betAmount);
        GameLobby storage newGame = games[gameIdCounter];
        newGame.player1 = msg.sender;
        newGame.player2 = _secondPlayer;
        newGame.betAmount = _betAmount;
        newGame.gameState = GameState.WaitingForSubmits;
        newGame.deadline = block.timestamp + _gameDuration;
        unchecked {
            gameIdCounter++;
        }
    }

    function joinGameLobby(uint256 _gameId)
        external
        GameLobbyWaitingForOpponent(_gameId)
        EnoughBalanceAvailable(msg.sender, games[_gameId].betAmount)
        NotExpiredGame(_gameId)
    {
        payBetEntry(msg.sender, games[_gameId].betAmount);
        GameLobby storage newGame = games[_gameId];
        newGame.player2 = msg.sender;
        newGame.gameState = GameState.WaitingForSubmits;
    }

    function submitHash(uint256 _gameId, bytes32 _hash) external GameLobbyWaitingForSubmit(_gameId){
        GameLobby memory gameInfo = games[_gameId];
        GameLobby storage game = games[_gameId];
        if (msg.sender == gameInfo.player1) {
            game.player1HashSubmit = _hash;
            if (gameInfo.player2HashSubmit != bytes32(0x0)){
                game.gameState = GameState.WaitingForChoiceDecryption;
            }
        } else if (msg.sender == gameInfo.player2) {
            game.player2HashSubmit = _hash;
            if (gameInfo.player1HashSubmit != bytes32(0x0)){
                game.gameState = GameState.WaitingForChoiceDecryption;
            }
        } else {
            revert NotGamePlayer();
        }
    }


    function checkGameState(uint256 _gameId) external NotExpiredGame(_gameId) {
        GameLobby memory game = games[_gameId];
        if (game.gameState != GameState.Finalized && game.gameState != GameState.NotInitialized) {
            games[_gameId].gameState = GameState.Finalized;
            checkResult(_gameId);
        } else {
            revert DeadlineNotReached();
        }
    }

    function checkResult(uint256 _gameId) private view returns (address winner) {}
}
