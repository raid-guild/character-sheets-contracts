// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {CharacterSheet} from "../lib/Structs.sol";

interface ICharacterSheets {
    function rollCharacterSheet(string calldata _tokenURI) external returns (uint256);

    function unequipItemFromCharacter(uint256 characterId, uint256 itemId) external;

    function equipItemToCharacter(uint256 characterId, uint256 itemId) external;

    function renounceSheet() external;

    function restoreSheet() external returns (address);

    function removeSheet(uint256 characterId) external;

    function updateCharacterMetadata(string calldata newCid) external;

    function jailPlayer(address playerAddress, bool throwInJail) external;

    function updateClones(address clonesStorage) external;

    function updateErc6551Registry(address newErc6551Storage) external;

    function updateErc6551CharacterAccount(address newERC6551CharacterAccount) external;

    function updateBaseUri(string memory _uri) external;

    function updateMetadataUri(string memory _uri) external;

    function approve(address to, uint256 characterId) external;

    function setApprovalForAll(address operator, bool approved) external;

    function transferFrom(address from, address to, uint256 characterId) external;

    function safeTransferFrom(address from, address to, uint256 characterId, bytes memory) external;

    function isItemEquipped(uint256 characterId, uint256 itemId) external view returns (bool);

    function getCharacterSheetByCharacterId(uint256 characterId) external view returns (CharacterSheet memory);

    function getCharacterIdByPlayerAddress(address _playerAddress) external view returns (uint256);

    function getCharacterIdByAccountAddress(address _account) external view returns (uint256);

    function tokenURI(uint256 characterId) external view returns (string memory);

    function supportsInterface(bytes4 interfaceId) external view returns (bool);

    function balanceOf(address) external view returns (uint256);

    function addExternalCharacter(address) external returns (uint256);
}
