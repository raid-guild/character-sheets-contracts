// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

/**
 * @title IHats Adaptor
 * @author MrDeadCe11
 * @notice This is an adaptor interface that allows the characterSheetsImplementation to check mint hats to players and characters
 */

interface IHatsAdaptor {
    function updateHatsAddress(address newHatsAddress) external;

    function updateAdminHatId(uint256 newAdminHatId) external;

    function updateDungeonMasterHatId(uint256 newDungeonMasterHatId) external;

    function updateCharacterHatModuleAddress(address newCharacterHatAddress) external;

    function updatePlayerHatModuleAddress(address newPlayerAddress) external;

    function mintCharacterHat(address wearer) external returns (bool);

    function mintPlayerHat(address wearer) external returns (bool);

    function checkCharacterHatEligibility(address account) external view returns (bool eligible, bool standing);

    function checkPlayerHatEligibility(address account) external view returns (bool eligible, bool standing);

    function isCharacter(address wearer) external view returns (bool);

    function isPlayer(address wearer) external view returns (bool);
}
