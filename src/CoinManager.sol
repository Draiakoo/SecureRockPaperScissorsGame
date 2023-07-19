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

    modifier MoreThanZero(uint256 amount) {
        if (amount == 0) {
            revert AmountCanNotBeZero();
        }
        _;
    }

    function deposit() external payable MoreThanZero(msg.value) {
        balances[msg.sender] += msg.value;
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
    }

    function payBetEntry(address _user, uint256 _betAmount) internal {
        balances[_user] -= _betAmount;
    }

    function payBetToWinner(address _user, uint256 _betAmount) internal {
        balances[_user] += _betAmount;
    }

    function balanceOf(address _user) public view returns (uint256 balance) {
        balance = balances[_user];
    }
}