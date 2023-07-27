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

contract CoinManager {
    error AmountCanNotBeZero();
    error NotEnoughBalance();
    error TransactionFailed();

    mapping(address user => uint256 amount) internal balances;

    event Deposit(address indexed depositor, uint256 indexed amount);
    event Withdraw(address indexed withdrawer, uint256 indexed amount);
    event EntryPayment(address indexed payer, uint256 indexed amount, uint256 indexed gameId);
    event GameReceiving(address indexed receiver, uint256 indexed amount, uint256 indexed gameId);

    modifier MoreThanZero(uint256 amount) {
        if (amount == 0) {
            revert AmountCanNotBeZero();
        }
        _;
    }

    function deposit() external payable MoreThanZero(msg.value) {
        balances[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    function withdraw(uint256 _amount) external MoreThanZero(_amount) {
        if (_amount > balances[msg.sender]) {
            revert NotEnoughBalance();
        }
        balances[msg.sender] -= _amount;
        (bool success,) = msg.sender.call{value: _amount}("");
        if (!success) {
            revert TransactionFailed();
        }
        emit Withdraw(msg.sender, _amount);
    }

    function payBetEntry(address _user, uint256 _betAmount, uint256 _gameId) internal {
        balances[_user] -= _betAmount;
        emit EntryPayment(_user, _betAmount, _gameId);
    }

    function payBetToWinner(address _user, uint256 _betAmount, uint256 _gameId) internal {
        balances[_user] += _betAmount;
        emit GameReceiving(_user, _betAmount, _gameId);
    }

    function balanceOf(address _user) public view returns (uint256 balance) {
        balance = balances[_user];
    }
}