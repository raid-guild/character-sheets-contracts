// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IHats Adaptor
 * @author MrDeadCe11
 * @notice This is an adaptor interface that allows contracts to  mint hats to players and characters
 * and check which accounts are wearing which hats.
 */
interface IHatsAdaptor {
    function updateHatsAddress(address newHatsAddress) external;

    function updateAdminHatId(uint256 newAdminHatId) external;

    function updateGameMasterHatId(uint256 newGameMasterHatId) external;

    function updateCharacterHatModuleAddress(address newCharacterHatAddress) external;

    function updatePlayerHatModuleAddress(address newPlayerAddress) external;

    function mintCharacterHat(address wearer) external returns (bool);

    function mintPlayerHat(address wearer) external returns (bool);

    function addNewGame(address newGame) external;

    function removeGame(uint256 gameIndex) external;

    function checkCharacterHatEligibility(address account) external view returns (bool eligible, bool standing);

    function checkPlayerHatEligibility(address account) external view returns (bool eligible, bool standing);

    function isCharacter(address wearer) external view returns (bool);

    function isPlayer(address wearer) external view returns (bool);

    function isGameMaster(address wearer) external view returns (bool);

    function isAdmin(address wearer) external view returns (bool);
}
