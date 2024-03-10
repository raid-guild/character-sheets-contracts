// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IClassLevelAdaptor {
    function getExpForLevel(uint256 desiredLevel) external view returns (uint256);
    function getCurrentLevel(uint256 expAmount) external view returns (uint256);
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}
