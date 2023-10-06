// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {CharacterSheet} from "../lib/Structs.sol";

interface ICharacterSheets {
    function getCharacterSheetByCharacterId(uint256 characterId) external view returns (CharacterSheet memory);

    function getCharacterIdByPlayerAddress(address _playerAddress) external view returns (uint256);

    function getCharacterIdByAccountAddress(address _account) external view returns (uint256);
}
