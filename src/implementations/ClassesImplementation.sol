// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Initializable} from "openzeppelin/proxy/utils/Initializable.sol";
import {ERC1155Receiver} from "openzeppelin/token/ERC1155/utils/ERC1155Receiver.sol";
import {ERC1155, ERC1155TokenReceiver} from "hats/lib/ERC1155/ERC1155.sol";
import {ERC1155Holder} from "openzeppelin/token/ERC1155/utils/ERC1155Holder.sol";
import {Counters} from "openzeppelin/utils/Counters.sol";

import {CharacterSheetsImplementation} from "../implementations/CharacterSheetsImplementation.sol";
import {ExperienceImplementation} from "../implementations/ExperienceImplementation.sol";
import {Class, CharacterSheet} from "../lib/Structs.sol";

import {Errors} from "../lib/Errors.sol";

/**
 * @title Experience and Items
 * @author MrDeadCe11
 * @notice this is an ERC1155 that is designed to interact with the characterSheets contract.
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
    ExperienceImplementation public experience;

    event NewClassCreated(uint256 erc1155TokenId, string name);
    event ClassAssigned(uint256 characterId, uint256 classId);
    event ClassRevoked(uint256 characterId, uint256 classId);
    event CharacterSheetsUpdated(address newCharacterSheets);

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

    function batchCreateClassType(bytes[] calldata classDatas)
        external
        onlyDungeonMaster
        returns (uint256[] memory tokenIds)
    {
        tokenIds = new uint256[](classDatas.length);

        for (uint256 i = 0; i < classDatas.length; i++) {
            bytes calldata classData = classDatas[i];
            tokenIds[i] = createClassType(classData);
        }
    }

    function claimClass(uint256 characterId, uint256 classId) external onlyCharacter returns (bool) {
        CharacterSheet memory character = characterSheets.getCharacterSheetByCharacterId(characterId);
        Class memory newClass = classes[classId];

        if (msg.sender != character.erc6551TokenAddress) {
            revert Errors.CharacterError();
        }

        if (!newClass.claimable) {
            revert Errors.ClaimableError();
        }

        _mint(character.erc6551TokenAddress, classId, 1, bytes(newClass.cid));

        classes[classId].supply++;

        emit ClassAssigned(characterId, classId);

        bool success = true;
        return success;
    }

    function assignClasses(uint256 characterId, uint256[] calldata _classIds) external onlyDungeonMaster {
        for (uint256 i = 0; i < _classIds.length; i++) {
            assignClass(characterId, _classIds[i]);
        }
    }

    function updateCharacterSheetsContract(address newCharSheets) external onlyDungeonMaster {
        characterSheets = CharacterSheetsImplementation(newCharSheets);
        emit CharacterSheetsUpdated(newCharSheets);
    }

    /**
     *
     * @param classData encoded class data includes
     *  - string name
     *  - string cid
     * @return tokenId the ERC1155 token id
     */

    function createClassType(bytes calldata classData) public onlyDungeonMaster returns (uint256 tokenId) {
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

    /**
     * gives an CHARACTER token a class.  can only assign one of each class type to each CHARACTER
     * @param characterId the tokenId of the player
     * @param classId the classId of the class to be assigned
     */

    function assignClass(uint256 characterId, uint256 classId) public onlyDungeonMaster {
        CharacterSheet memory character = characterSheets.getCharacterSheetByCharacterId(characterId);
        Class memory newClass = classes[classId];

        if (character.memberAddress == address(0x0)) {
            revert Errors.CharacterError();
        }
        if (newClass.tokenId == 0) {
            revert Errors.ClassError();
        }
        if (balanceOf(character.erc6551TokenAddress, newClass.tokenId) != 0) {
            revert Errors.ClassError();
        }

        _mint(character.erc6551TokenAddress, classId, 1, bytes(newClass.cid));

        classes[classId].supply++;

        emit ClassAssigned(characterId, classId);
    }

    /**
     * removes a class from a character token
     * @param characterId the token Id of the player who needs a class removed
     * @param classId the class to be removed
     */

    function revokeClass(uint256 characterId, uint256 classId) public returns (bool success) {
        if (classId == 0 || characterId == 0) {
            revert Errors.ClassError();
        }

        CharacterSheet memory sheet = characterSheets.getCharacterSheetByCharacterId(characterId);

        if (sheet.memberAddress != msg.sender && sheet.erc6551TokenAddress != msg.sender) {
            revert Errors.OwnershipError();
        }

        _burn(sheet.erc6551TokenAddress, classId, 1);

        success = true;
        emit ClassRevoked(characterId, classId);
    }

    function levelClass(uint256 classId) public onlyCharacter {
        uint256 balance = balanceOf(msg.sender, classId);

        if (balance < 1) {
            revert Errors.ClassError();
        }

        //#todo create an adapter that decides on the EXP amount required to acheive levels and implement here
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
        (string memory name, bool claimable, string memory cid) = abi.decode(classData, (string, bool, string));

        return Class(0, name, 0, claimable, cid);
    }

    // overrides

    /// @notice Only dungeon master can transfer classes. approval of character is not required

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) public override onlyDungeonMaster {
        require(ids.length == amounts.length, "LENGTH_MISMATCH");

        // require(msg.sender == from || isApprovedForAll[from][msg.sender], "NOT_AUTHORIZED");

        // Storing these outside the loop saves ~15 gas per iteration.
        uint256 id;
        uint256 amount;

        for (uint256 i = 0; i < ids.length;) {
            id = ids[i];
            amount = amounts[i];

            _balanceOf[from][id] -= amount;
            _balanceOf[to][id] += amount;

            // An array can't have a total length
            // larger than the max uint256 value.
            unchecked {
                ++i;
            }
        }

        emit TransferBatch(msg.sender, from, to, ids, amounts);

        require(
            to.code.length == 0
                ? to != address(0)
                : ERC1155TokenReceiver(to).onERC1155BatchReceived(msg.sender, from, ids, amounts, data)
                    == ERC1155TokenReceiver.onERC1155BatchReceived.selector,
            "UNSAFE_RECIPIENT"
        );
    }

    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes calldata data)
        public
        override
        onlyDungeonMaster
    {
        // require(msg.sender == from || isApprovedForAll[from][msg.sender], "NOT_AUTHORIZED");

        _balanceOf[from][id] -= amount;
        _balanceOf[to][id] += amount;

        emit TransferSingle(msg.sender, from, to, id, amount);

        require(
            to.code.length == 0
                ? to != address(0)
                : ERC1155TokenReceiver(to).onERC1155Received(msg.sender, from, id, amount, data)
                    == ERC1155TokenReceiver.onERC1155Received.selector,
            "UNSAFE_RECIPIENT"
        );
    }
}
