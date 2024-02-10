pragma solidity ^0.8.20;

// SPDX-License-Identifier: MIT

interface IMultiERC6551HatsEligibilityModule {
    function addValidGame(address newGame) external;
    function addValidGames(address[] calldata newGames) external;
    function removeGame(uint256 gameIndex) external;
}
