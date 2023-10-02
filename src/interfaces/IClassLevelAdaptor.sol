// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface IClassLevelAdaptor {
    function getExpForLevel(uint256 desiredLevel) external view returns (uint256);

    /// @notice getExperienceForNextLevel checks the amount of exp required to level a class
    /// @dev this checks the adaptor contract which must implement the correct erc165 interface in order to determine exp requirements
    /// @param currentLevel the current level of the class that wants to be leveled
    /// @return uint256 the amount of exp required for the next level
    function getExperienceForNextLevel(uint256 currentLevel) external view returns (uint256);

    function levelRequirementsMet(address account, uint256 currentLevel) external view returns (bool);
}
