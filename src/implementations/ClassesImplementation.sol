// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC1155Upgradeable} from "openzeppelin-contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import {ERC1155HolderUpgradeable} from
    "openzeppelin-contracts-upgradeable/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";
import {UUPSUpgradeable} from "openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {Class} from "../lib/Structs.sol";
import {Errors} from "../lib/Errors.sol";

import {IClassLevelAdaptor} from "../interfaces/IClassLevelAdaptor.sol";
import {IHatsAdaptor} from "../interfaces/IHatsAdaptor.sol";
import {IClonesAddressStorage} from "../interfaces/IClonesAddressStorage.sol";
import {IExperience} from "../interfaces/IExperience.sol";
import "forge-std/console2.sol";
/**
 * @title Experience and Items
 * @author MrDeadCe11 && dan13ram
 * @notice this is an ERC1155 that is designed to interact with the characterSheets contract.
 * Each item and class is an 1155 token that can soulbound or not to the erc6551 wallet of each player nft
 * in the characterSheets contract.
 */

contract ClassesImplementation is ERC1155HolderUpgradeable, ERC1155Upgradeable, UUPSUpgradeable {
    /// @dev individual mapping for token URIs
    mapping(uint256 => string) private _classURIs;

    /// @dev base URI
    string private _baseURI = "";

    /// @dev mapping of class token types.  the class Id is the location in this mapping of the class.
    mapping(uint256 => Class) private _classes;

    mapping(address account => mapping(uint256 classId => uint256 classExp)) private _expPerClass;

    /// @dev the total number of class types that have been created
    uint256 public totalClasses;

    IClonesAddressStorage public clones;

    event NewClassCreated(uint256 tokenId);
    event BaseURIUpdated(string newUri);
    event ClassAssigned(address character, uint256 classId);
    event ClassRevoked(address character, uint256 classId);
    event ClassLeveled(address character, uint256 classId, uint256 newBalance);
    event ClonesAddressStorageUpdated(address newClonesAddressStorage);
    event ClassExpGiven(address characterAccount, uint256 classId, uint256 amountOfExp);
    event ClassExpRevoked(address characterAccount, uint256 classId, uint256 amountOfExp);

    modifier onlyAdmin() {
        if (!IHatsAdaptor(clones.hatsAdaptor()).isAdmin(msg.sender)) {
            revert Errors.AdminOnly();
        }
        _;
    }

    modifier onlyGameMaster() {
        if (!IHatsAdaptor(clones.hatsAdaptor()).isGameMaster(msg.sender)) {
            revert Errors.GameMasterOnly();
        }
        _;
    }

    modifier onlyCharacter() {
        if (!IHatsAdaptor(clones.hatsAdaptor()).isCharacter(msg.sender)) {
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
        address _clonesStorageAdaptor;
        (_clonesStorageAdaptor, baseUri) = abi.decode(_encodedData, (address, string));
        _baseURI = baseUri;
        clones = IClonesAddressStorage(_clonesStorageAdaptor);
    }

    /**
     * @dev Sets `baseURI` as the `_baseURI` for all tokens
     */
    function setBaseURI(string memory _baseUri) external onlyAdmin {
        _baseURI = _baseUri;
        emit BaseURIUpdated(_baseUri);
    }

    /**
     * @dev Sets `tokenURI` as the tokenURI of `tokenId`.
     */
    function setURI(uint256 tokenId, string memory tokenURI) external onlyAdmin {
        _classURIs[tokenId] = tokenURI;
        emit URI(uri(tokenId), tokenId);
    }

    function claimClass(uint256 classId) external onlyCharacter returns (bool success) {
        Class storage newClass = _classes[classId];

        if (!newClass.claimable) {
            revert Errors.ClaimableError();
        }

        _mint(msg.sender, classId, 1, "");

        _classes[classId].supply++;

        emit ClassAssigned(msg.sender, classId);

        success = true;
    }

    function updateClonesAddressStorage(address newClonesStorage) external onlyAdmin {
        clones = IClonesAddressStorage(newClonesStorage);
        emit ClonesAddressStorageUpdated(newClonesStorage);
    }

    /**
     *
     * @param classData encoded class data includes
     *  - string cid
     * @return tokenId the ERC1155 token id
     */
    function createClassType(bytes calldata classData) external onlyGameMaster returns (uint256 tokenId) {
        _createClass(classData);

        emit NewClassCreated(totalClasses);
        emit URI(uri(totalClasses), totalClasses);

        return totalClasses;
    }

    function giveClassExp(address characterAccount, uint256 classId, uint256 amountOfExp) public onlyGameMaster {
        // todo add some verification that the amount of exp given is valid according to experince rules (e.g. relating to stablecoin distribution or what have you)
        if (!IHatsAdaptor(clones.hatsAdaptor()).isCharacter(characterAccount)) {
            revert Errors.CharacterError();
        }
        _expPerClass[characterAccount][classId] += amountOfExp;
        emit ClassExpGiven(characterAccount, classId, amountOfExp);
    }

    function revokeClassExp(address characterAccount, uint256 classId, uint256 amountOfExp) public onlyGameMaster {
        if (!IHatsAdaptor(clones.hatsAdaptor()).isCharacter(characterAccount)) {
            revert Errors.CharacterError();
        }
        _expPerClass[characterAccount][classId] -= amountOfExp;
        emit ClassExpRevoked(characterAccount, classId, amountOfExp);
    }

    /**
     * gives an CHARACTER token a class.  can only assign one of each class type to each CHARACTER
     * @param character the tokenId of the player
     * @param classId the classId of the class to be assigned
     */
    function assignClass(address character, uint256 classId) public onlyGameMaster {
        if (character == address(0x0)) {
            revert Errors.CharacterError();
        }

        if (classId > totalClasses) {
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
     * removes a class from a character token must be called by the character account or the game master
     * @param character the token Id of the player who needs a class removed
     * @param classId the class to be removed
     */
    function revokeClass(address character, uint256 classId) public onlyGameMaster returns (bool success) {
        return _revokeClass(character, classId);
    }

    function renounceClass(uint256 classId) public onlyCharacter returns (bool success) {
        return _revokeClass(msg.sender, classId);
    }

    function getClassExp(address characterAccount, uint256 classId) public view returns (uint256 exp) {
        exp = _expPerClass[characterAccount][classId];
    }

    /**
     * @dev See {IERC1155-balanceOf}.
     */
    function balanceOf(address account, uint256 classId) public view override returns (uint256 balance) {
        balance = super.balanceOf(account, classId);
        if (balance == 0) {
            return 0;
        } else if (balance == 1) {
            uint256 expAmount = _expPerClass[account][classId];
            balance = IClassLevelAdaptor(clones.classLevelAdaptor()).getCurrentLevel(expAmount);
        }
    }

    function classExpBalance(address characterAccount, uint256 classId) public view returns (uint256 classExp) {
        return _expPerClass[characterAccount][classId];
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
        override(ERC1155Upgradeable, ERC1155HolderUpgradeable)
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

    function _createClass(bytes calldata classData) internal returns (uint256 tokenId) {
        (bool claimable, string memory cid) = abi.decode(classData, (bool, string));
        totalClasses++;
        tokenId = totalClasses;
        _classes[tokenId] = Class({claimable: claimable, supply: 0});
        _classURIs[tokenId] = cid;
    }

    // overrides

    /**
     * @notice Only game master can transfer _classes. approval of character is not required
     */
    //solhint-disable-next-line
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public override onlyGameMaster {
        if (!IHatsAdaptor(clones.hatsAdaptor()).isCharacter(to)) {
            revert Errors.CharacterOnly();
        }

        super._safeBatchTransferFrom(from, to, ids, amounts, data);
    }

    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes memory data)
        public
        override
        onlyGameMaster
    {
        if (!IHatsAdaptor(clones.hatsAdaptor()).isCharacter(to)) {
            revert Errors.CharacterOnly();
        }
        super._safeTransferFrom(from, to, id, amount, data);
    }

    function _revokeClass(address character, uint256 classId) internal returns (bool success) {
        if (classId > totalClasses) {
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
    function _authorizeUpgrade(address newImplementation) internal override onlyGameMaster {}
}
