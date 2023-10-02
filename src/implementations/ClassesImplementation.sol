// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {ERC1155Upgradeable} from "openzeppelin-contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import {
    ERC1155HolderUpgradeable,
    ERC1155ReceiverUpgradeable
} from "openzeppelin-contracts-upgradeable/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";
import {UUPSUpgradeable} from "openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IAccessControl} from "openzeppelin-contracts/access/IAccessControl.sol";

import {IExperience} from "../interfaces/IExperience.sol";
import {Class} from "../lib/Structs.sol";
import {Errors} from "../lib/Errors.sol";

import {IClassLevelAdaptor} from "../interfaces/IClassLevelAdaptor.sol";
import {IClasses} from "../interfaces/IClasses.sol";

/**
 * @title Experience and Items
 * @author MrDeadCe11 && dan13ram
 * @notice this is an ERC1155 that is designed to interact with the characterSheets contract.
 * Each item and class is an 1155 token that can soulbound or not to the erc6551 wallet of each player nft
 * in the characterSheets contract.
 */
contract ClassesImplementation is IClasses, ERC1155HolderUpgradeable, ERC1155Upgradeable, UUPSUpgradeable {
    bytes32 public constant DUNGEON_MASTER = keccak256("DUNGEON_MASTER");
    bytes32 public constant CHARACTER = keccak256("CHARACTER");

    /// @dev individual mapping for token URIs
    mapping(uint256 => string) private _classURIs;

    /// @dev character => classId => exp staked
    mapping(address => mapping(uint256 => uint256)) public classLevels;

    /// @dev base URI
    string private _baseURI = "";

    /// @dev mapping of class token types.  the class Id is the location in this mapping of the class.
    mapping(uint256 => Class) private _classes;

    /// @dev the total number of class types that have been created
    uint256 public totalClasses;

    /// @dev the interface to the characterSheets erc721 implementation that this is tied to
    address public characterSheets;
    address public experience;

    address public classLevelAdaptor;

    event NewClassCreated(uint256 tokenId);
    event ClassAssigned(address character, uint256 classId);
    event ClassRevoked(address character, uint256 classId);
    event CharacterSheetsUpdated(address newCharacterSheets);
    event ExperienceUpdated(address newExperience);
    event ClassLevelAdaptorUpdated(address newClassLevelAdaptor);
    event ClassLeveled(address character, uint256 classId, uint256 newLevel);

    modifier onlyDungeonMaster() {
        if (!IAccessControl(characterSheets).hasRole(DUNGEON_MASTER, msg.sender)) {
            revert Errors.DungeonMasterOnly();
        }
        _;
    }

    modifier onlyCharacter() {
        if (!IAccessControl(characterSheets).hasRole(CHARACTER, msg.sender)) {
            revert Errors.CharacterOnly();
        }
        _;
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(bytes calldata _encodedData) external initializer {
        __UUPSUpgradeable_init();
        __ERC1155Holder_init();

        string memory baseUri;
        (characterSheets, experience, classLevelAdaptor, baseUri) =
            abi.decode(_encodedData, (address, address, address, string));
        _baseURI = baseUri;
    }

    /**
     * @dev Sets `baseURI` as the `_baseURI` for all tokens
     */
    function setBaseURI(string memory _baseUri) external onlyDungeonMaster {
        _baseURI = _baseUri;
    }

    /**
     * @dev Sets `tokenURI` as the tokenURI of `tokenId`.
     */
    function setURI(uint256 tokenId, string memory tokenURI) external onlyDungeonMaster {
        _classURIs[tokenId] = tokenURI;
        emit URI(uri(tokenId), tokenId);
    }

    function claimClass(uint256 classId) external onlyCharacter returns (bool) {
        if (!IAccessControl(characterSheets).hasRole(CHARACTER, msg.sender)) {
            revert Errors.CharacterError();
        }
        Class storage newClass = _classes[classId];

        if (!newClass.claimable) {
            revert Errors.ClaimableError();
        }

        _mint(msg.sender, classId, 1, "");

        _classes[classId].supply++;

        emit ClassAssigned(msg.sender, classId);

        bool success = true;
        return success;
    }

    function updateCharacterSheetsContract(address newCharSheets) external onlyDungeonMaster {
        characterSheets = newCharSheets;
        emit CharacterSheetsUpdated(newCharSheets);
    }

    function updateExperienceContract(address newExperience) external onlyDungeonMaster {
        experience = newExperience;
        emit ExperienceUpdated(newExperience);
    }

    function updateClassLevelAdaptor(address newClassLevelAdaptor) external onlyDungeonMaster {
        classLevelAdaptor = newClassLevelAdaptor;
        emit ClassLevelAdaptorUpdated(newClassLevelAdaptor);
    }

    /**
     *
     * @param classData encoded class data includes
     *  - string cid
     * @return tokenId the ERC1155 token id
     */

    function createClassType(bytes calldata classData) external onlyDungeonMaster returns (uint256 tokenId) {
        uint256 _tokenId = totalClasses;

        _createClass(classData, _tokenId);

        emit NewClassCreated(_tokenId);
        emit URI(uri(_tokenId), _tokenId);
        totalClasses++;

        return _tokenId;
    }

    /**
     * gives an CHARACTER token a class.  can only assign one of each class type to each CHARACTER
     * @param character the tokenId of the player
     * @param classId the classId of the class to be assigned
     */

    function assignClass(address character, uint256 classId) public onlyDungeonMaster {
        if (character == address(0x0)) {
            revert Errors.CharacterError();
        }
        if (classId >= totalClasses) {
            revert Errors.ClassError();
        }
        if (balanceOf(character, classId) != 0) {
            revert Errors.TokenBalanceError();
        }

        _mint(character, classId, 1, "");

        _classes[classId].supply++;

        emit ClassAssigned(character, classId);
    }

    /**
     * removes a class from a character token must be called by the character account or the dungeon master
     * @param character the token Id of the player who needs a class removed
     * @param classId the class to be removed
     */

    function revokeClass(address character, uint256 classId) public onlyDungeonMaster returns (bool success) {
        return _revokeClass(character, classId);
    }

    function renounceClass(uint256 classId) public onlyCharacter returns (bool success) {
        return _revokeClass(msg.sender, classId);
    }
    /**
     * @notice This will level the class of any character class if they have enough exp
     * @dev As a source of truth, only the dungeon master can call this function so that the correct _classes are leveld
     * @param character the address of the character account to have a class leveled
     * @param classId the Id of the class that will be leveled
     * @return uint256 class token balance
     */

    function levelClass(address character, uint256 classId) public onlyDungeonMaster returns (uint256) {
        if (classLevelAdaptor == address(0)) {
            revert Errors.NotInitialized();
        }
        if (!IClassLevelAdaptor(classLevelAdaptor).levelRequirementsMet(character, classId)) {
            revert Errors.ClassError();
        }

        uint256 currentLevel = balanceOf(character, classId);
        uint256 requiredAmount = IClassLevelAdaptor(classLevelAdaptor).getExperienceForNextLevel(currentLevel);

        //stake appropriate exp
        classLevels[character][classId] += requiredAmount;

        IExperience(experience).burnExp(character, requiredAmount);

        //mint another class token

        _mint(character, classId, 1, "");

        uint256 newLevel = balanceOf(character, classId);

        emit ClassLeveled(character, classId, newLevel);

        return newLevel;
    }

    function deLevelClass(uint256 classId, uint256 numberOfLevels) public onlyCharacter returns (uint256) {
        if (classLevelAdaptor == address(0)) {
            revert Errors.NotInitialized();
        }
        uint256 currentLevel = balanceOf(msg.sender, classId) - 1;

        if (currentLevel < numberOfLevels) {
            revert Errors.InsufficientBalance();
        }

        uint256 expToRedeem = IClassLevelAdaptor(classLevelAdaptor).getExpForLevel(currentLevel)
            - IClassLevelAdaptor(classLevelAdaptor).getExpForLevel(currentLevel - numberOfLevels);

        //remove level tokens
        _burn(msg.sender, classId, numberOfLevels);

        //mint replacement exp

        IExperience(experience).giveExp(msg.sender, expToRedeem);

        //return amount of exp minted

        return expToRedeem;
    }

    /**
     * @return an array of all Class structs stored in the _classes mapping
     */

    function getAllClasses() public view returns (Class[] memory) {
        Class[] memory allClasses = new Class[](totalClasses);
        for (uint256 i = 1; i <= totalClasses; i++) {
            allClasses[i - 1] = _classes[i];
        }
        return allClasses;
    }

    function getClass(uint256 classId) public view returns (Class memory) {
        return _classes[classId];
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC1155Upgradeable, ERC1155ReceiverUpgradeable)
        returns (bool)
    {
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

    function _createClass(bytes calldata classData, uint256 tokenId) internal {
        (bool claimable, string memory cid) = abi.decode(classData, (bool, string));

        _classes[tokenId] = Class({claimable: claimable, supply: 0});
        _classURIs[tokenId] = cid;
    }

    // overrides

    /**
     * @notice Only dungeon master can transfer _classes. approval of character is not required
     */
    //solhint-disable-next-line
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public override onlyDungeonMaster {
        if (!IAccessControl(characterSheets).hasRole(CHARACTER, to)) {
            revert Errors.CharacterOnly();
        }

        super._safeBatchTransferFrom(from, to, ids, amounts, data);
    }

    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes memory data)
        public
        override
        onlyDungeonMaster
    {
        if (!IAccessControl(characterSheets).hasRole(CHARACTER, to)) {
            revert Errors.CharacterOnly();
        }
        super._safeTransferFrom(from, to, id, amount, data);
    }

    function _revokeClass(address character, uint256 classId) internal returns (bool success) {
        if (classId >= totalClasses) {
            revert Errors.ClassError();
        }

        // must be level 0 to revoke.  if class is leveled the character must delevel the class to 0
        if (balanceOf(character, classId) != 1) {
            revert Errors.TokenBalanceError();
        }

        _burn(character, classId, 1);

        success = true;
        emit ClassRevoked(character, classId);
    }

    //solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address newImplementation) internal override onlyDungeonMaster {}
}
