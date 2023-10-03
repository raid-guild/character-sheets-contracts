// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
pragma abicoder v2;

import { CharacterSheet } from "../lib/Structs.sol";

interface ICharacterSheets {
    function hasRole(bytes32 role, address account) external view returns (bool);

    function getCharacterSheetByCharacterId(uint256 characterId) external view returns (CharacterSheet memory);

    function getCharacterIdByPlayerAddress(address _playerAddress) external view returns (uint256);
}
