// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Initializable} from "openzeppelin/proxy/utils/Initializable.sol";
import {MerkleProof} from "openzeppelin/utils/cryptography/MerkleProof.sol";
import {Strings} from "openzeppelin/utils/Strings.sol";
import {ERC1155Receiver} from "openzeppelin/token/ERC1155/utils/ERC1155Receiver.sol";
import {ERC1155} from "hats/lib/ERC1155/ERC1155.sol";
import {IERC721} from "openzeppelin/token/ERC721/IERC721.sol";
import {ERC1155Holder} from "openzeppelin/token/ERC1155/utils/ERC1155Holder.sol";
import {Counters} from "openzeppelin/utils/Counters.sol";

import {CharacterSheetsImplementation} from "../implementations/CharacterSheetsImplementation.sol";
import {Item, Class, CharacterSheet} from "../lib/Structs.sol";

import {Errors} from "../lib/Errors.sol";

/**
 * @title Experience and Items
 * @author MrDeadCe11
 * @notice this is an ERC721 that is designed to intereact with the characterSheets contract.
 * Each item and class is an 1155 token that can soulbound or not to the erc6551 wallet of each player nft
 * in the characterSheets contract.
 */
contract ClassesImplementation is ERC1155Holder, Initializable, ERC1155 {
    using Counters for Counters.Counter;

    Counters.Counter private _classIdCounter;

    bytes32 public constant DUNGEON_MASTER = keccak256("DUNGEON_MASTER");
    bytes32 public constant PLAYER = keccak256("PLAYER");
    bytes32 public constant CHARACTER = keccak256("CHARACTER");

    /// @dev individual mapping for token URIs
    mapping(uint256 => string) private _classURIs;

    /// @dev base URI
    string private _baseURI = "";

    /// @dev individual mapping for token URIs
    mapping(uint256 => string) private _classTokenURIs;

    /// @dev mapping of class token types.  the class Id is the location in this mapping of the class.
    mapping(uint256 => Class) public classes;

    /// @dev the total number of class types that have been created
    uint256 public totalClasses;

    /// @dev the interface to the characterSheets erc721 implementation that this is tied to
    CharacterSheetsImplementation public characterSheets;

    event NewClassCreated(uint256 erc1155TokenId, string name);
    event ClassAssigned(uint256 characterId, uint256 classId);
    event ClassRevoked(uint256 characterId, uint256 classId);

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

    constructor() {
        _disableInitializers();
    }

    function initialize(bytes calldata _encodedData) external initializer {
        address characterSheetsAddress;
        string memory baseUri;
        (characterSheetsAddress, baseUri) = abi.decode(_encodedData, (address, string));
        _baseURI = baseUri;
        characterSheets = CharacterSheetsImplementation(characterSheetsAddress);

        _classIdCounter.increment();
    }

    /**
     *
     * @param classData encoded class data includes
     *  - string name
     *  - uint256 supply
     *  - string cid
     * @return tokenId the ERC1155 token id
     */

    function createClassType(bytes calldata classData) external onlyDungeonMaster returns (uint256 tokenId) {
        Class memory _newClass = _createClassStruct(classData);

        uint256 _tokenId = _classIdCounter.current();

        _newClass.tokenId = _tokenId;

        classes[_tokenId] = _newClass;

        _setURI(_tokenId, _newClass.cid);

        emit NewClassCreated(_tokenId, _newClass.name);
        totalClasses++;
        _classIdCounter.increment();

        return _tokenId;
    }

    function assignClasses(uint256 characterId, uint256[] calldata _classIds) external onlyDungeonMaster {
        for (uint256 i = 0; i < _classIds.length; i++) {
            assignClass(characterId, _classIds[i]);
        }
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

        _mint(player.ERC6551TokenAddress, classId, 1, bytes(newClass.cid));

        classes[classId].supply++;

        emit ClassAssigned(characterId, classId);
    }

    /**
     * removes a class from a player token
     * @param characterId the token Id of the player who needs a class removed
     * @param classId the class to be removed
     */

    function revokeClass(uint256 characterId, uint256 classId) public returns (bool success) {
        if (classId == 0 || characterId == 0) {
            revert Errors.ClassError();
        }

        CharacterSheet memory sheet = characterSheets.getCharacterSheetByCharacterId(characterId);

        if (characterSheets.hasRole(DUNGEON_MASTER, msg.sender)) {
            if (characterSheets.isClassEquipped(characterId, classId)) {
                if (!characterSheets.unequipClassFromCharacter(characterId, classId)) {
                    revert Errors.ClassError();
                }
            }
        } else {
            if (sheet.memberAddress != msg.sender && sheet.ERC6551TokenAddress != msg.sender) {
                revert Errors.OwnershipError();
            }
            if (characterSheets.isClassEquipped(characterId, classId)) {
                if (!characterSheets.unequipClassFromCharacter(characterId, classId)) {
                    revert Errors.ClassError();
                }
            }
        }

        _burn(sheet.ERC6551TokenAddress, classId, 1);

        success = true;
        emit ClassRevoked(characterId, classId);
    }

    /**
     *
     * @param name the name of the class.  is case sensetive.
     * @return classId storage location of the class in the classes mapping
     */

    function findClassByName(string calldata name) public view returns (uint256 classId) {
        string memory temp = name;
        for (uint256 i = 0; i <= totalClasses; i++) {
            if (keccak256(abi.encode(classes[i].name)) == keccak256(abi.encode(temp))) {
                classId = classes[i].tokenId;
                return classId;
            }
        }
        revert Errors.ClassError();
    }

    /**
     * returns an array of all Class structs stored in the classes mapping
     */

    function getAllClasses() public view returns (Class[] memory) {
        Class[] memory allClasses = new Class[](totalClasses);
        for (uint256 i = 1; i <= totalClasses; i++) {
            allClasses[i - 1] = classes[i];
        }
        return allClasses;
    }

    function getClassById(uint256 classId) public view returns (Class memory) {
        return classes[classId];
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC1155, ERC1155Receiver) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC1155MetadataURI-uri}.
     *
     * This implementation returns the concatenation of the `_baseURI`
     * and the token-specific uri if the latter is set
     *
     * This enables the following behaviors:
     *
     * - if `_tokenURIs[tokenId]` is set, then the result is the concatenation
     *   of `_baseURI` and `_tokenURIs[tokenId]` (keep in mind that `_baseURI`
     *   is empty per default);
     *
     * - if `_tokenURIs[tokenId]` is NOT set then we fallback to `super.uri()`
     *   which in most cases will contain `ERC1155._uri`;
     *
     * - if `_tokenURIs[tokenId]` is NOT set, and if the parents do not have a
     *   uri value set, then the result is empty.
     */

    function uri(uint256 tokenId) public view override returns (string memory) {
        string memory tokenURI = _classURIs[tokenId];
        // If token URI is set, concatenate base URI and tokenURI (via abi.encodePacked).
        return bytes(tokenURI).length > 0 ? string(abi.encodePacked(_baseURI, tokenURI)) : _baseURI;
    }

    function getBaseURI() public view returns (string memory) {
        return _baseURI;
    }
    /**
     * @dev Sets `tokenURI` as the tokenURI of `tokenId`.
     */

    function _setURI(uint256 tokenId, string memory tokenURI) internal {
        _classURIs[tokenId] = tokenURI;
        emit URI(uri(tokenId), tokenId);
    }

    function _createClassStruct(bytes calldata classData) private pure returns (Class memory) {
        (string memory name, string memory cid) = abi.decode(classData, (string, string));

        return Class(0, name, 0, cid);
    }
}
