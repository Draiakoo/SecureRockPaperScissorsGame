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

/// @title RockPaperScissors secure game
/// @author Pol Ureña
/// @notice This contract is a simple rock paper scissors game that is intended to be secured on-chain so nobody could try to get advantage against other players.
/// @dev This game implements the mythic rock paper scissors game but implemented on-chain in a secure manner. The flow force players to encrypt their choice into a hash for later decryption once both players submited its hash. So it can't be tricked in any way nor be frontrunned.

contract RockPaperScissorsGame is CoinManager {
    error WrongGameState();
    error GameExpired();
    error DeadlineNotReached();
    error NotGamePlayer();
    error GameTooShort();
    error GameSpotReserved();
    error InvalidChoice();
    error ChoiceAndPasswordNotMatching();
    error YouCanNotJoinAGameYouCreated();
    error NotGameCreator();

    /// @dev Different available choices. By default, the choice is encrypted because it has to be revealed with the hash
    enum Choice {
        Encrypted,
        Rock,
        Paper,
        Scissors
    }

    /// @dev Different states of a GameLobby.
    ///         - When a game has not been created, it has the NotInitialized state
    ///         - When a game has been created, but needs to be filled with an other player, is in LookingForOpponent state
    ///         - When a game has 2 players registered, the game is in WaitingForSubmits state where it needs to get the choice hash of both players
    ///         - When a game has the 2 choice hashes of the players, the game is in WaitingForChoiceDecryption state where it needs to get the decryption of the submited hash to determine the choice of both players
    ///         - When a game has the choice revealed of both players, the game is Finalized
    enum GameState {
        NotInitialized,
        LookingForOpponent,
        WaitingForSubmits,
        WaitingForChoiceDecryption,
        Finalized
    }

    /// @dev GameLobby information:
    ///         - player1 address of the first player (the creator of the lobby)
    ///         - player2 address of the second player
    ///         - betAmount amount of the bet that players have to pay to play in this lobby. The winner will receive 2*betAmount
    ///         - player1HashSubmit hash of the first player choice
    ///         - player2HashSubmit hash of the second player choice
    ///         - player1DecryptedChoice decrypted player 1 choice from the submited hash
    ///         - player2DecryptedChoice decrypted player 2 choice from the submited hash
    ///         - gameState current state of the game lobby
    ///         - deadline timestamp when the game will finish and will no longer be available to play with
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

    /// Register of all games
    mapping(uint256 gameId => GameLobby game) private games;

    /// Simple counter to track the gameId
    uint256 public gameIdCounter;

    bytes32 public immutable rockHash;
    bytes32 public immutable paperHash;
    bytes32 public immutable scissorsHash;

    event GameCreated(uint256 indexed gameId, address indexed creator, uint256 indexed betAmount);
    event GameStarted(uint256 indexed gameId, address indexed player, uint256 indexed betAmount);
    event GameFinished(
        uint256 indexed gameId, address indexed winner, uint256 indexed betAmount
    );

    /// @dev Modifier to check if the game is in a specific state
    modifier GameLobbyInSpecificState(uint256 _gameId, GameState state) {
        if (games[_gameId].gameState != state) {
            revert WrongGameState();
        }
        _;
    }

    /// @dev Modifier to check if game deadline has expired
    modifier NotExpiredGame(uint256 _gameId) {
        if (games[_gameId].deadline < block.timestamp) {
            revert GameExpired();
        }
        _;
    }

    /// @dev Modifier to check if the game duration introduced to create the game lobby is greater than or equal 1 day (minimum duration)
    modifier MinimumGameDuration1day(uint256 _gameDuration) {
        if (_gameDuration < 1 days) {
            revert GameTooShort();
        }
        _;
    }

    /// @dev Modifier to check if the sender has enough balance to pay the bet
    modifier EnoughBalanceAvailable(address _user, uint256 _amount) {
        if (balances[_user] < _amount) {
            revert NotEnoughBalance();
        }
        _;
    }

    constructor() {
        rockHash = keccak256(abi.encodePacked("Rock"));
        paperHash = keccak256(abi.encodePacked("Paper"));
        scissorsHash = keccak256(abi.encodePacked("Scissors"));
    }

    /// @param _betAmount The amount of ETH that will bet every player for this specific game.
    /// @param _gameDuration The maximum time that the game will be available to interact with.
    /// @param _secondPlayer Optional parameter, if it is the 0 address, the game is open for everybody, if not, the spot for the second player is reserved for the provided address.
    /// @dev It checks that the creator has enough balance to pay the game bet and initializes the GameLobby struct correspondigly to the games registry.

    function createLobby(uint256 _betAmount, uint256 _gameDuration, address _secondPlayer)
        external
        EnoughBalanceAvailable(msg.sender, _betAmount)
        MinimumGameDuration1day(_gameDuration)
    {
        payBetEntry(msg.sender, _betAmount, gameIdCounter);
        GameLobby storage newGame = games[gameIdCounter];
        newGame.player1 = msg.sender;
        if (_secondPlayer != address(0)) {
            newGame.player2 = _secondPlayer;
        }
        newGame.betAmount = _betAmount;
        newGame.gameState = GameState.LookingForOpponent;
        newGame.deadline = block.timestamp + _gameDuration;
        emit GameCreated(gameIdCounter, msg.sender, _betAmount);
        unchecked {
            gameIdCounter++;
        }
    }

    /// @param _gameId The gameId of the game that you want to cancel.
    /// @dev It checks if the game is LookingForOpponent, the deadline has not expired and the sender is the game creator.
    /// @notice This function enables the game creator to cancel the game and get his bet amount back. A game is only cancellable in "waitingForOpponent" state.

    function cancelGameLobby(uint256 _gameId) external 
        GameLobbyInSpecificState(_gameId, GameState.LookingForOpponent)
        NotExpiredGame(_gameId)
    {
        GameLobby storage gameInfo = games[_gameId];
        if(gameInfo.player1 != msg.sender){
            revert NotGameCreator();
        }
        payBetToWinner(msg.sender, gameInfo.betAmount, _gameId);
        delete games[_gameId];
    }

    /// @param _gameId The gameId of the game that you want to join.
    /// @dev It checks if the game is LookingForOpponent, the sender has enough balance to pay the game bet.
    /// @notice If the second slot is reserved for somebody it registers the sender if it was the address reserved or reverts if not. On the other hand, if the spot was free it just registers the sender.

    function joinGameLobby(uint256 _gameId)
        external
        GameLobbyInSpecificState(_gameId, GameState.LookingForOpponent)
        EnoughBalanceAvailable(msg.sender, games[_gameId].betAmount)
        NotExpiredGame(_gameId)
    {
        GameLobby storage newGame = games[_gameId];
        if(newGame.player1 == msg.sender){
            revert YouCanNotJoinAGameYouCreated();
        }
        address secondPlayer = games[_gameId].player2;
        if (secondPlayer != address(0)) {
            if (msg.sender == secondPlayer) {
                payBetEntry(msg.sender, games[_gameId].betAmount, _gameId);
                newGame.gameState = GameState.WaitingForSubmits;
                emit GameStarted(_gameId, msg.sender, newGame.betAmount);
            } else {
                revert GameSpotReserved();
            }
        } else {
            payBetEntry(msg.sender, games[_gameId].betAmount, _gameId);
            newGame.player2 = msg.sender;
            newGame.gameState = GameState.WaitingForSubmits;
            emit GameStarted(_gameId, msg.sender, newGame.betAmount);
        }
    }

    /// @param _gameId The gameId of the game that you want to submit the hash.
    /// @param _hash The choice + the password hashed.
    /// @dev It first checks if the game is waiting for submitions, the deadline has not expired and that the sender is one of the players registered in the lobby.
    /// @notice When a player submits his hash and the other has already done it, the state of the game changes to WaitingForChoiceDecryption.
    /// @notice A player can change its hash if the other has not alreadu submited it.
    /// @notice A player that would already submited his hash could frontrun the other player to change his hash just before the second one but would not receive any valuable information since the choice is encrypted into the hash.

    function submitHash(uint256 _gameId, bytes32 _hash)
        external
        GameLobbyInSpecificState(_gameId, GameState.WaitingForSubmits)
        NotExpiredGame(_gameId)
    {
        GameLobby memory gameInfo = games[_gameId];
        GameLobby storage game = games[_gameId];
        if (msg.sender == gameInfo.player1) {
            game.player1HashSubmit = _hash;
            if (gameInfo.player2HashSubmit != bytes32(0x0)) {
                game.gameState = GameState.WaitingForChoiceDecryption;
            }
        } else if (msg.sender == gameInfo.player2) {
            game.player2HashSubmit = _hash;
            if (gameInfo.player1HashSubmit != bytes32(0x0)) {
                game.gameState = GameState.WaitingForChoiceDecryption;
            }
        } else {
            revert NotGamePlayer();
        }
    }

    /// @param _gameId The gameId of the game that you want to submit the choice.
    /// @param _choice The choice that you chose when hashing. It is only accepted the following choice: Rock, Paper, Scissors.
    /// @param _password The password used to generate the hash
    /// @dev It checks all the following conditions:
    ///          - Check if the game is waiting for decryption choices
    ///          - Check if the choice is valid
    ///          - Check if the sender is one of the players
    ///          - Check if the choice and password provided matches
    /// @notice When a player submits his choice and the other has already done it, the state of the game changes to Finalized.
    /// @notice A player can NOT change the choice he made when he submited the hash.
    /// @notice Once a player has decrypted his choice, the other can see his choice but it is computationally impossible to find a password that combined with the winning choice matches the submited hash by this player.

    function submitChoice(uint256 _gameId, string calldata _choice, string calldata _password)
        external
        GameLobbyInSpecificState(_gameId, GameState.WaitingForChoiceDecryption)
        NotExpiredGame(_gameId)
    {
        bytes32 choiceHash = keccak256(abi.encodePacked(_choice));
        if (choiceHash != rockHash && choiceHash != paperHash && choiceHash != scissorsHash) {
            revert InvalidChoice();
        }
        Choice submitedChoice;
        if (choiceHash == rockHash) {
            submitedChoice = Choice.Rock;
        } else if (choiceHash == paperHash) {
            submitedChoice = Choice.Paper;
        } else {
            submitedChoice = Choice.Scissors;
        }
        GameLobby memory gameInfo = games[_gameId];
        if (msg.sender == gameInfo.player1) {
            if (keccak256(abi.encodePacked(_choice, _password)) == gameInfo.player1HashSubmit) {
                games[_gameId].player1DecryptedChoice = submitedChoice;
                if (gameInfo.player2DecryptedChoice != Choice.Encrypted) {
                    games[_gameId].gameState = GameState.Finalized;
                    checkResult(_gameId);
                }
            } else {
                revert ChoiceAndPasswordNotMatching();
            }
        } else if (msg.sender == gameInfo.player2) {
            if (keccak256(abi.encodePacked(_choice, _password)) == gameInfo.player2HashSubmit) {
                games[_gameId].player2DecryptedChoice = submitedChoice;
                if (gameInfo.player1DecryptedChoice != Choice.Encrypted) {
                    games[_gameId].gameState = GameState.Finalized;
                    checkResult(_gameId);
                }
            } else {
                revert ChoiceAndPasswordNotMatching();
            }
        } else {
            revert NotGamePlayer();
        }
    }

    /// @param _gameId The gameId of the game that you want to check it's state.
    /// @dev It checks if a game has surpased it's deadline. It is intended to avoid Denial of Service since a player can refuse to submit it's choice once he knows that he will lose for example. This way, once the deadline is surpased, the other player can claim it's reward.
    /// @notice It can only be triggered by one of the players.

    function checkGameState(uint256 _gameId) external {
        GameLobby memory game = games[_gameId];
        if (msg.sender != game.player1 && msg.sender != game.player2){
            revert NotGamePlayer();
        }
        if (
            game.gameState != GameState.Finalized && game.gameState != GameState.NotInitialized
                && game.deadline < block.timestamp
        ) {
            games[_gameId].gameState = GameState.Finalized;
            checkResult(_gameId);
        } else {
            revert DeadlineNotReached();
        }
    }

    /// @param _gameId The gameId of the game that you want to check it's result.
    /// @dev This function checks all the possible cases of DoS, these possibilities are the following ones:
    ///          - If the deadline is over and nobody has submited a hash, the result is a tie
    ///          - If the deadline is over and just one of the players submited a hash, this player is the winner
    ///          - If the deadline is over and no players submited their choice, the result is a tie
    ///          - If the deadline is over and just one of the players submited his choice, this player is the winner
    ///          - If the deadline is over and both choices has been submited, check the result of the game
    /// @notice When winner is assigned the zero address is to consider a tie.

    function checkResult(uint256 _gameId) private {
        address winner;
        GameLobby memory game = games[_gameId];
        if (game.player1HashSubmit == 0 && game.player2HashSubmit == 0) {
            winner = address(0);
        } else if (game.player1HashSubmit != 0 && game.player2HashSubmit == 0) {
            winner = game.player1;
        } else if (game.player1HashSubmit == 0 && game.player2HashSubmit != 0) {
            winner = game.player2;
        } else if (game.player1DecryptedChoice == Choice.Encrypted && game.player2DecryptedChoice == Choice.Encrypted) {
            winner = address(0);
        } else if (game.player1DecryptedChoice != Choice.Encrypted && game.player2DecryptedChoice == Choice.Encrypted) {
            winner = game.player1;
        } else if (game.player1DecryptedChoice == Choice.Encrypted && game.player2DecryptedChoice != Choice.Encrypted) {
            winner = game.player2;
        } else {
            winner = gameLogic(game.player1DecryptedChoice, game.player2DecryptedChoice, game.player1, game.player2);
        }

        // Update balances for winner
        if (winner == address(0)) {
            payBetToWinner(game.player1, game.betAmount, _gameId);
            payBetToWinner(game.player2, game.betAmount, _gameId);
        } else {
            payBetToWinner(winner, game.betAmount * 2, _gameId);
        }

        // Emit an event to track results
        emit GameFinished(_gameId, winner, game.betAmount);

        // Delete game struct to free space
        // delete games[_gameId];
    }

    /// @param player1Choice Player1's choice
    /// @param player2Choice Player2's choice
    /// @param player1 Player1's address
    /// @param player1 Player2's address
    /// @dev This function determines and returns the winner of the game based on their choices.
    /// @dev All the possible implemented scenarios are the following ones:
    ///         - Rock vs Rock: It's a tie
    ///         - Rock vs Paper: Paper wins
    ///         - Rock vs Scissors: Rock wins
    ///         - Paper vs Rock: Paper wins
    ///         - Paper vs Paper: It's a tie
    ///         - Paper vs Scissors: Scissors win
    ///         - Scissors vs Rock: Rock wins
    ///         - Scissors vs Paper: Scissors win
    ///         - Scissors vs Scissors: It's a tie

    function gameLogic(Choice player1Choice, Choice player2Choice, address player1, address player2)
        private
        pure
        returns (address winner)
    {
        if (player1Choice == Choice.Rock) {
            if (player2Choice == Choice.Rock) {
                winner = address(0);
            } else if (player2Choice == Choice.Paper) {
                winner = player2;
            } else {
                winner = player1;
            }
        } else if (player1Choice == Choice.Paper) {
            if (player2Choice == Choice.Paper) {
                winner = address(0);
            } else if (player2Choice == Choice.Scissors) {
                winner = player2;
            } else {
                winner = player1;
            }
        } else {
            if (player2Choice == Choice.Scissors) {
                winner = address(0);
            } else if (player2Choice == Choice.Rock) {
                winner = player2;
            } else {
                winner = player1;
            }
        }
    }

    /// @param _gameId The gameId of the game that you want to obtain all it's information.
    /// @dev This function is only to check the information of a game.

    function gameInformation(uint256 _gameId) public view returns (GameLobby memory) {
        return games[_gameId];
    }
}