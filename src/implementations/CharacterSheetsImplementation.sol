// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
pragma abicoder v2;

import {
    ERC721URIStorageUpgradeable,
    ERC721Upgradeable,
    IERC721Upgradeable
} from "openzeppelin-contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import {UUPSUpgradeable} from "openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IERC1155} from "openzeppelin-contracts/token/ERC1155/IERC1155.sol";

import {IERC6551Registry} from "../interfaces/IERC6551Registry.sol";
import {IEligibilityAdaptor} from "../interfaces/IEligibilityAdaptor.sol";
import {IHatsAdaptor} from "../interfaces/IHatsAdaptor.sol";
import {IItems} from "../interfaces/IItems.sol";
import {IClonesAddressStorage} from "../interfaces/IClonesAddressStorage.sol";

import {ImplementationAddressStorage} from "../lib/ImplementationAddressStorage.sol";

import {CharacterSheet} from "../lib/Structs.sol";
import {Errors} from "../lib/Errors.sol";

/**
 * @title Character Sheets
 * @author MrDeadCe11 && dan13ram
 * @notice This is a gamified reputation managment system desgigned for raid guild but
 * left composable for use with any dao or organization
 * @dev this is an erc721 contract that calculates the erc6551 address of every token at token creation and then uses that address as the character for
 * a rpg themed reputation system with experience points awarded by a centralized authority the "DUNGEON_MASTER" and items and classes that can be owned and equipped
 * by the base character account.
 */

contract CharacterSheetsImplementation is ERC721URIStorageUpgradeable, UUPSUpgradeable {
    /// @dev the admin of the contract
    bytes32 public constant DUNGEON_MASTER = keccak256("DUNGEON_MASTER");
    /// @dev the EOA of the dao member who owns a sheet
    bytes32 public constant PLAYER = keccak256("PLAYER");
    /// @dev the tokenbound account of the sheet nft
    bytes32 public constant CHARACTER = keccak256("CHARACTER");

    address public items;

    string public baseTokenURI;
    string public metadataURI;

    ImplementationAddressStorage public erc6551Addresses;
    IClonesAddressStorage public clones;

    // characterId => characterSheet
    mapping(uint256 => CharacterSheet) private _sheets;
    // playerAddress => characterId
    mapping(address => uint256) private _playerSheets;
    // characterAddress => characterId
    mapping(address => uint256) private _characterSheets;

    mapping(address => bool) public jailed;

    uint256 public totalSheets;

    event NewCharacterSheetRolled(address player, address account, uint256 characterId);
    event MetadataURIUpdated(string newURI);
    event BaseURIUpdated(string newURI);
    event CharacterRemoved(uint256 characterId);
    event Erc6551AddressesUpdated(address newErc6551Storage);
    event ClonesAddressStorageUpdated(address newClonesStorageAddress);
    event ItemEquipped(uint256 characterId, uint256 itemId);
    event ItemUnequipped(uint256 characterId, uint256 itemId);
    event CharacterUpdated(uint256 characterId);
    event PlayerJailed(address playerAddress, bool thrownInJail);
    event CharacterRestored(address player, address account, uint256 characterId);

    modifier onlyContract() {
        if (msg.sender != clones.itemsClone()) {
            revert Errors.CallerNotApproved();
        }
        _;
    }

    modifier onlyAdmin() {
        if (!IHatsAdaptor(clones.hatsAdaptorClone()).isAdmin(msg.sender)) {
            revert Errors.CallerNotApproved();
        }
        _;
    }

    modifier onlyDungeonMaster() {
        if (!IHatsAdaptor(clones.hatsAdaptorClone()).isDungeonMaster(msg.sender)) {
            revert Errors.DungeonMasterOnly();
        }
        _;
    }

    modifier onlyPlayer() {
        if (!IHatsAdaptor(clones.hatsAdaptorClone()).isPlayer(msg.sender)) {
            revert Errors.PlayerOnly();
        }
        _;
    }

    modifier onlyCharacter() {
        if (!IHatsAdaptor(clones.hatsAdaptorClone()).isCharacter(msg.sender)) {
            revert Errors.CharacterOnly();
        }
        _;
    }

    //solhint-disable-next-line
    constructor() {
        _disableInitializers();
    }

    /**
     *
     * @param _encodedParameters encoded parameters must include:
     * - address daoAddress: the address of the dao who's member list will be allowed to become players and who
     *      will be able to interact with this contract
     * - address[] dungeonMasters: an array addresses of the person/persons who are authorized to issue player
     *      cards, classes, and items.
     * - address owner: the account that will have the DEFAULT_ADMIN role
     * - address CharacterAccountImplementation: the erc 4337 implementation of the Character account.
     * - address erc6551Registry:  the address of the deployed ERC6551 registry on whichever chain these
     *      contracts are on
     * - string metadataURI: the metadata for the character sheets implementation
     * - string baseURI: the default uri of the player card images, arbitrary a different uri can be set
     *      when the character sheet is minted.
     * - address itemsImplementation: this is the address of the ERC1155 items contract associated
     *      with this contract.  this is assigned at contract creation.
     */

    function initialize(bytes calldata _encodedParameters) external initializer {
        __ERC721_init_unchained("CharacterSheet", "CHAS");
        __UUPSUpgradeable_init();

        address clonesStorage;
        address implementationStorage;

        (clonesStorage, implementationStorage, metadataURI, baseTokenURI) =
            abi.decode(_encodedParameters, (address, address, string, string));
        clones = IClonesAddressStorage(clonesStorage);
        erc6551Addresses = ImplementationAddressStorage(implementationStorage);
    }

    /**
     *
     * @param _tokenURI the uri of the character sheet metadata
     * if no uri is stored then it will revert to the base uri of the contract
     */

    function rollCharacterSheet(string calldata _tokenURI) external returns (uint256) {
        if (
            erc6551Addresses.erc6551AccountImplementation() == address(0)
                || erc6551Addresses.erc6551Registry() == address(0)
        ) {
            revert Errors.NotInitialized();
        }

        // check the eligibility adaptor to see if the player is eligible to roll a character sheet
        if (
            clones.eligibilityAdaptorClone() != address(0)
                && !IEligibilityAdaptor(clones.eligibilityAdaptorClone()).isEligible(msg.sender)
        ) {
            revert Errors.EligibilityError();
        }

        if (jailed[msg.sender]) {
            revert Errors.Jailed();
        }

        if (balanceOf(msg.sender) != 0) {
            revert Errors.TokenBalanceError();
        }

        uint256 existingCharacterId = _playerSheets[msg.sender];

        if (existingCharacterId != 0 || _sheets[existingCharacterId].playerAddress == msg.sender) {
            // must restore sheet
            revert Errors.PlayerError();
        }

        uint256 characterId = totalSheets;

        // calculate ERC6551 account address
        address characterAccount = IERC6551Registry(erc6551Addresses.erc6551Registry()).createAccount(
            erc6551Addresses.erc6551AccountImplementation(), block.chainid, address(this), characterId, characterId, ""
        );
        // setting salt as characterId

        _sheets[characterId] =
            CharacterSheet({accountAddress: characterAccount, playerAddress: msg.sender, inventory: new uint256[](0)});

        _safeMint(msg.sender, characterId);
        _setTokenURI(characterId, _tokenURI);
        _playerSheets[msg.sender] = characterId;
        _characterSheets[characterAccount] = characterId;

        IHatsAdaptor(clones.hatsAdaptorClone()).mintPlayerHat(msg.sender);
        IHatsAdaptor(clones.hatsAdaptorClone()).mintCharacterHat(characterAccount);

        totalSheets++;
        emit NewCharacterSheetRolled(msg.sender, characterAccount, characterId);
        return characterId;
    }

    /**
     * unequips an item from the character sheet inventory
     * @param characterId the player to have the item type from their inventory
     * @param characterId the erc1155 token id of the item to be unequipped
     */

    function unequipItemFromCharacter(uint256 characterId, uint256 itemId) external onlyCharacter {
        if (msg.sender != _sheets[characterId].accountAddress) {
            revert Errors.OwnershipError();
        }

        if (IERC1155(clones.itemsClone()).balanceOf(msg.sender, itemId) == 0) {
            // TODO ensure that when items are transferred from a character sheet that they are unequipped
            revert Errors.InventoryError();
        }

        uint256[] memory arr = _sheets[characterId].inventory;

        bool success;
        for (uint256 i = 0; i < arr.length; i++) {
            if (arr[i] == itemId) {
                for (uint256 j = i; j < arr.length; j++) {
                    if (j + 1 < arr.length) {
                        arr[j] = arr[j + 1];
                    } else if (j + 1 >= arr.length) {
                        arr[j] = 0;
                    }
                }

                _sheets[characterId].inventory = arr;
                _sheets[characterId].inventory.pop();

                success = true;
                break;
            }
        }

        if (success) {
            emit ItemUnequipped(characterId, itemId);
        } else {
            revert Errors.InventoryError();
        }
    }

    /**
     * adds an item to the items in the character sheet inventory
     * @param characterId the id of the player receiving the item
     * @param itemId the itemId of the item
     */

    function equipItemToCharacter(uint256 characterId, uint256 itemId) external onlyCharacter {
        if (msg.sender != _sheets[characterId].accountAddress) {
            revert Errors.OwnershipError();
        }

        if (IERC1155(items).balanceOf(msg.sender, itemId) < 1) {
            revert Errors.InsufficientBalance();
        }

        if (isItemEquipped(characterId, itemId)) {
            revert Errors.InventoryError();
        }

        _sheets[characterId].inventory.push(itemId);
        emit ItemEquipped(characterId, itemId);
    }

    /**
     * this will burn the nft of the player.  only a player can burn their own token.
     */

    function renounceSheet() external onlyPlayer {
        uint256 _characterId = _playerSheets[msg.sender];

        if (_ownerOf(_characterId) != msg.sender) {
            revert Errors.OwnershipError();
        }

        _burn(_characterId);

        emit CharacterRemoved(_characterId);
    }

    /**
     * restores a previously renounced sheet if called by the wrong player and incorrect address will be created that does not control any assets
     * @return the ERC6551 account address
     */

    function restoreSheet() external returns (address) {
        uint256 characterId = _playerSheets[msg.sender];

        if (_ownerOf(characterId) != address(0)) {
            revert Errors.OwnershipError();
        }
        if (
            clones.eligibilityAdaptorClone() != address(0)
                && !IEligibilityAdaptor(clones.eligibilityAdaptorClone()).isEligible(msg.sender)
        ) {
            revert Errors.EligibilityError();
        }
        if (jailed[msg.sender]) {
            revert Errors.Jailed();
        }
        address restoredAccount = IERC6551Registry(erc6551Addresses.erc6551Registry()).createAccount(
            erc6551Addresses.erc6551AccountImplementation(), block.chainid, address(this), characterId, characterId, ""
        );
        // setting salt as characterId

        if (_sheets[characterId].playerAddress != msg.sender) {
            revert Errors.PlayerError();
        }
        if (_sheets[characterId].accountAddress != restoredAccount) {
            revert Errors.CharacterError();
        }

        _safeMint(msg.sender, characterId);

        emit CharacterRestored(msg.sender, restoredAccount, characterId);

        return restoredAccount;
    }

    /**
     * Burns a players characterSheet.  can only be done if there is a passing guild kick proposal
     * @param characterId the characterId of the player to be removed.
     */

    function removeSheet(uint256 characterId) external onlyDungeonMaster {
        address playerAddress = _ownerOf(characterId);
        if (playerAddress == address(0)) {
            revert Errors.CharacterError();
        }

        if (
            clones.eligibilityAdaptorClone() != address(0)
                && IEligibilityAdaptor(clones.eligibilityAdaptorClone()).isEligible(playerAddress)
        ) {
            revert Errors.EligibilityError();
        }

        if (!jailed[playerAddress]) {
            revert Errors.Jailed();
        }

        _burn(characterId);

        emit CharacterRemoved(characterId);
    }

    /**
     * allows a player to update the character metadata in the contract
     * @param newCid the new metadata URI
     */
    function updateCharacterMetadata(string calldata newCid) external onlyPlayer {
        uint256 characterId = _playerSheets[msg.sender];

        if (_ownerOf(characterId) != msg.sender) {
            revert Errors.OwnershipError();
        }

        _setTokenURI(characterId, newCid);

        emit CharacterUpdated(characterId);
    }

    function jailPlayer(address playerAddress, bool throwInJail) external onlyDungeonMaster {
        jailed[playerAddress] = throwInJail;
        emit PlayerJailed(playerAddress, throwInJail);
    }

    function updateClones(address clonesStorage) public onlyAdmin {
        clones = IClonesAddressStorage(clonesStorage);
        emit ClonesAddressStorageUpdated(clonesStorage);
    }

    function updateErc6551Addresses(address newErc6551Storage) public onlyAdmin {
        erc6551Addresses = ImplementationAddressStorage(newErc6551Storage);
        emit Erc6551AddressesUpdated(newErc6551Storage);
    }

    function setBaseUri(string memory _uri) public onlyDungeonMaster {
        baseTokenURI = _uri;
        emit BaseURIUpdated(_uri);
    }

    function setMetadataUri(string memory _uri) public onlyDungeonMaster {
        metadataURI = _uri;
        emit MetadataURIUpdated(_uri);
    }

    // transfer overrides since these tokens should be soulbound or only transferable by the dungeonMaster

    /**
     * @dev See {IERC721-approve}.
     */

    function approve(address to, uint256 characterId) public virtual override(ERC721Upgradeable, IERC721Upgradeable) {
        return super.approve(to, characterId);
    }

    /**
     * @dev See {IERC721-setApprovalForAll}.
     */
    function setApprovalForAll(address operator, bool approved)
        public
        virtual
        override(ERC721Upgradeable, IERC721Upgradeable)
    {
        return super.setApprovalForAll(operator, approved);
    }

    /**
     * @dev See {IERC721-transferFrom}.
     */
    function transferFrom(address from, address to, uint256 characterId)
        public
        virtual
        override(ERC721Upgradeable, IERC721Upgradeable)
        onlyDungeonMaster
    {
        if (_playerSheets[to] != 0) {
            revert Errors.TokenBalanceError();
        }
        _playerSheets[to] = characterId;

        // TODO: update sheet erc6551 account address

        return super.transferFrom(from, to, characterId);
    }

    /**
     * revert(Errors."This token cannot be transfered");
     * revert(Errors."This token cannot be transfered");
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(address from, address to, uint256 characterId)
        public
        virtual
        override(ERC721Upgradeable, IERC721Upgradeable)
        onlyDungeonMaster
    {
        if (_sheets[_playerSheets[to]].playerAddress != address(0)) {
            revert Errors.CharacterError();
        }
        _playerSheets[to] = characterId;
        _sheets[characterId].playerAddress = to;

        // TODO: update sheet erc6551 account address

        return super.safeTransferFrom(from, to, characterId);
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(address from, address to, uint256 characterId, bytes memory data)
        public
        virtual
        override(ERC721Upgradeable, IERC721Upgradeable)
        onlyDungeonMaster
    {
        if (_sheets[_playerSheets[to]].playerAddress != address(0)) {
            revert Errors.CharacterError();
        }
        _playerSheets[to] = characterId;
        _sheets[characterId].playerAddress = to;

        // TODO: update sheet erc6551 account address

        return super.safeTransferFrom(from, to, characterId, data);
    }

    function getCharacterSheetByCharacterId(uint256 characterId) public view returns (CharacterSheet memory) {
        if (_ownerOf(characterId) == address(0)) {
            revert Errors.CharacterError();
        }
        return _sheets[characterId];
    }

    function getCharacterIdByAccountAddress(address _account) public view returns (uint256 id) {
        return _characterSheets[_account];
    }

    function getCharacterIdByPlayerAddress(address _player) public view returns (uint256) {
        uint256 characterId = _playerSheets[_player];
        if (_ownerOf(characterId) != _player) {
            revert Errors.CharacterError();
        }
        return characterId;
    }

    function isItemEquipped(uint256 characterId, uint256 itemId) public view returns (bool) {
        if (_ownerOf(characterId) == address(0)) {
            revert Errors.CharacterError();
        }

        CharacterSheet storage sheet = _sheets[characterId];
        if (sheet.inventory.length == 0) {
            return false;
        }
        uint256 supply = IItems(items).getItem(itemId).supply;
        if (supply == 0) {
            revert Errors.ItemError();
        }

        for (uint256 i; i < sheet.inventory.length; i++) {
            if (sheet.inventory[i] == itemId) {
                return true;
            }
        }
        return false;
    }

    function tokenURI(uint256 characterId) public view override returns (string memory) {
        return super.tokenURI(characterId);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721URIStorageUpgradeable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    //solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address newImplementation) internal override onlyAdmin {}

    function _baseURI() internal view virtual override returns (string memory) {
        return baseTokenURI;
    }
}
