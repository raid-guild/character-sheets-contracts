// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
pragma abicoder v2;

interface IClassLevelAdaptor {
    /// @notice getExperienceForNextLevel checks the amount of exp required to level a class
    /// @dev this checks the adaptor contract which must implement the correct erc165 interface in order to determine exp requirements
    /// @param currentLevel the current level of the class that wants to be leveled
    /// @return uint256 the amount of exp required for the next level
    function getExperienceForNextLevel(uint256 currentLevel) external pure returns (uint256);

    function levelRequirementsMet(address account, uint256 currentLevel) external pure returns (bool);

    function supportsInterface(bytes4 interfaceId) external pure returns (bool);
}
