// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {MerkleProof} from "openzeppelin/utils/cryptography/MerkleProof.sol";
import {Strings} from "openzeppelin/utils/Strings.sol";
import {ERC1155Receiver} from "openzeppelin/token/ERC1155/utils/ERC1155Receiver.sol";
import {ERC1155, ERC1155TokenReceiver} from "hats-protocol/lib/ERC1155/ERC1155.sol";
import {IERC721} from "openzeppelin/token/ERC721/IERC721.sol";
import {ERC1155Holder} from "openzeppelin/token/ERC1155/utils/ERC1155Holder.sol";
import {Counters} from "openzeppelin/utils/Counters.sol";

import {CharacterSheetsImplementation} from "../implementations/CharacterSheetsImplementation.sol";
import {Item, Class, CharacterSheet} from "../lib/Structs.sol";

//solhint-disable-next-line
import "../lib/Errors.sol";

/**
 * @title Experience and Items
 * @author MrDeadCe11
 * @notice this is an ERC721 that is designed to intereact with the characterSheets contract.
 * Each item and class is an 1155 token that can soulbound or not to the erc6551 wallet of each player nft
 * in the characterSheets contract.
 */
contract ClassImplementation is ERC1155Holder, Initializable, ERC721 {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;

    /// @dev mapping of class token types.  the class Id is the location in this mapping of the class.
    mapping(uint256 => Class) public classes;

    /// @dev the total number of class types that have been created
    uint256 public totalClasses;

    /// @dev the interface to the characterSheets erc721 implementation that this is tied to
    CharacterSheetsImplementation public characterSheets;

    event NewClassCreated(uint256 erc1155TokenId, uint256 classId, string name);
    event ClassAssigned(address classAssignedTo, uint256 erc1155TokenId, uint256 classId);

    modifier onlyDungeonMaster() {
        if (!characterSheets.hasRole(DUNGEON_MASTER, msg.sender)) {
            revert Errors.DungeonMasterOnly();
        }
        _;
    }

    modifier onlyPlayer() {
        if (!characterSheets.hasRole(PLAYER, msg.sender)) {
            revert Errors.PlayerOnly();
        }
        _;
    }

    modifier onlyCharacter() {
        if (!characterSheets.hasRole(CHARACTER, msg.sender)) {
            revert Errors.CharacterOnly();
        }
        _;
    }

    function initialize(bytes calldata _encodedData) external initializer {
        address owner;
        address characterSheetsAddress;
        address hatsAddress;
        string memory baseUri;
        (owner, characterSheetsAddress, hatsAddress, baseUri) =
            abi.decode(_encodedData, (address, address, address, string));
        _baseURI = baseUri;
        characterSheets = CharacterSheetsImplementation(characterSheetsAddress);

        _tokenIdCounter.increment();
    }

    /**
     *
     * @param classData encoded class data includes
     *  - string name
     *  - uint256 supply
     *  - string cid
     * @return tokenId the ERC1155 token id
     * @return classId the location of the class struct in the classes mapping
     */

    function createClassType(bytes calldata classData)
        external
        onlyDungeonMaster
        returns (uint256 tokenId, uint256 classId)
    {
        Class memory _newClass = _createClassStruct(classData);

        uint256 _tokenId = _tokenIdCounter.current();

        _newClass.tokenId = _tokenId;

        classes[_tokenId] = _newClass;

        _setURI(_tokenId, _newClass.cid);
    
        emit NewClassCreated(_tokenId, _newClass.name);
        totalClasses++;
        _classesCounter.increment();
        _tokenIdCounter.increment();

        return _tokenId;
    }

    function assignClasses(uint256 characterId, uint256[] calldata _classIds) external onlyDungeonMaster {
        for (uint256 i = 0; i < _classIds.length; i++) {
            assignClass(characterId, _classIds[i]);
        }
    }

    function equipClass(uint256 characterId, uint256 classId) external onlyCharacter returns (bool) {
        CharacterSheet memory sheet = characterSheets.getCharacterSheetByCharacterId(characterId);
        Class memory class = classes[classId];
        if (balanceOf(sheet.ERC6551TokenAddress, class.tokenId) != 1) {
            revert Errors.ClassError();
        }
        if (msg.sender != sheet.ERC6551TokenAddress) {
            revert Errors.CharacterOnly();
        }
        characterSheets.equipClassToCharacter(characterId, classId);
        return true;
    }

    function unequipClass(uint256 characterId, uint256 classId) external onlyCharacter returns (bool) {
        CharacterSheet memory sheet = characterSheets.getCharacterSheetByCharacterId(characterId);
        Class memory class = classes[classId];
        if (balanceOf(sheet.ERC6551TokenAddress, class.tokenId) != 1) {
            revert Errors.ClassError();
        }
        if (msg.sender != sheet.ERC6551TokenAddress) {
            revert Errors.CharacterOnly();
        }
        characterSheets.equipClassToCharacter(characterId, classId);
        return true;
    }

    /**
     * gives an CHARACTER token a class.  can only assign one of each class type to each CHARACTER
     * @param characterId the tokenId of the player
     * @param classId the classId of the class to be assigned
     */

    function assignClass(uint256 characterId, uint256 classId) public onlyDungeonMaster {
        CharacterSheet memory player = characterSheets.getCharacterSheetByCharacterId(characterId);
        Class memory newClass = classes[classId];

        if (player.memberAddress == address(0x0)) {
            revert Errors.PlayerError();
        }
        if (newClass.tokenId == 0) {
            revert Errors.ClassError();
        }
        if (balanceOf(player.ERC6551TokenAddress, newClass.tokenId) != 0) {
            revert Errors.ClassError();
        }

        _mint(player.ERC6551TokenAddress, newClass.tokenId, 1, bytes(newClass.cid));

        classes[classId].supply++;

        emit ClassAssigned(player.ERC6551TokenAddress, newClass.tokenId, classId);
    }

    /**
     * removes a class from a player token
     * @param characterId the token Id of the player who needs a class removed
     * @param classId the class to be removed
     */

    function revokeClass(uint256 characterId, uint256 classId) public returns (bool success) {
        CharacterSheet memory sheet = characterSheets.getCharacterSheetByCharacterId(characterId);
        uint256 tokenId = classes[classId].tokenId;
        if (tokenId == 0) {
            revert Errors.ClassError();
        }
        if (characterSheets.hasRole(DUNGEON_MASTER, msg.sender)) {
            if (characterSheets.isClassEquipped(characterId, classId)) {
                if (!characterSheets.unequipClassFromCharacter(characterId, classId)) {
                    revert Errors.ClassError();
                }
            }
            _burn(sheet.ERC6551TokenAddress, tokenId, 1);
        } else {
            if (sheet.memberAddress != msg.sender && sheet.ERC6551TokenAddress != msg.sender) {
                revert Errors.OwnershipError();
            }
            if (characterSheets.isClassEquipped(characterId, classId)) {
                if (!characterSheets.unequipClassFromCharacter(characterId, classId)) {
                    revert Errors.ClassError();
                }
            }
            _burn(sheet.ERC6551TokenAddress, tokenId, 1);
        }
        success = true;
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
