// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {MerkleProof} from "openzeppelin-contracts/utils/cryptography/MerkleProof.sol";
import {ERC1155Upgradeable} from "openzeppelin-contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import {ERC1155HolderUpgradeable} from
    "openzeppelin-contracts-upgradeable/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";
import {ERC721HolderUpgradeable} from
    "openzeppelin-contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import {UUPSUpgradeable} from "openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {Errors} from "../lib/Errors.sol";
import {MultiToken, Asset} from "../lib/MultiToken.sol";
import {IItemsManager} from "../interfaces/IItemsManager.sol";
import {IClonesAddressStorage} from "../interfaces/IClonesAddressStorage.sol";
//solhint-disable-next-line
import "../lib/Structs.sol";

import {IHatsAdaptor} from "../interfaces/IHatsAdaptor.sol";

// import "forge-std/console2.sol";
/**
 * @title Experience and Items
 * @author MrDeadCe11 && dan13ram
 * @notice this is an ERC1155 that is designed to intereact with the characterSheets contract.
 * Each item and class is an 1155 token that can soulbound or not to the erc6551 wallet of each player nft
 * in the characterSheets contract.
 */
contract ItemsImplementation is
    ERC1155HolderUpgradeable,
    ERC1155Upgradeable,
    ERC721HolderUpgradeable,
    UUPSUpgradeable
{
    bytes4 private constant _INTERFACE_ID_ERC2981 = 0x2a55205a;

    /// @dev base URI
    string private _baseURI = "";

    /// @dev mapping itemId => uris for metadata
    mapping(uint256 => string) private _itemURIs;
    /// @dev mapping itemId => item struct for item types
    mapping(uint256 => Item) private _items;
    /// @dev itemId => character address => nonce : mapping to keep track of the nonce for claims made by an address
    mapping(uint256 => mapping(address => uint256)) internal _claimNonce;

    /// @dev the total number of item types that have been created
    uint256 public totalItemTypes;

    IClonesAddressStorage public clones;

    IItemsManager public itemsManager;

    event NewItemTypeCreated(uint256 itemId);
    event BaseURIUpdated(string newUri);
    event ItemClaimed(address character, uint256 itemId, uint256 amount);
    event ItemCrafted(address character, uint256 itemId, uint256 amount);
    event ItemDismantled(address character, uint256 itemId, uint256 amount);
    event ItemClaimableUpdated(uint256 itemId, bytes32 merkleRoot, uint256 newDistribution);
    event ItemDeleted(uint256 itemId);
    event ItemsManagerUpdated(address newItemsManager);

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

        address clonesStorage;
        (clonesStorage, _baseURI) = abi.decode(_encodedData, (address, string));
        clones = IClonesAddressStorage(clonesStorage);
        itemsManager = IItemsManager(clones.itemsManager());
    }

    /**
     * drops loot and/or exp after a completed quest items dropped through dropLoot do cost exp.
     * @param characters the tokenbound accounts of the character CHARACTER to receive the item
     * @param itemIds the item Id's of the loot to be dropped  exp is allways Item Id 0;
     * @param amounts the amounts of each item to be dropped this must be in sync with the item ids
     */
    function dropLoot(address[] calldata characters, uint256[][] calldata itemIds, uint256[][] calldata amounts)
        external
        onlyGameMaster
        returns (bool success)
    {
        if (characters.length != itemIds.length || itemIds.length != amounts.length) {
            revert Errors.LengthMismatch();
        }
        for (uint256 i; i < characters.length; i++) {
            for (uint256 j; j < itemIds[i].length; j++) {
                // dm should be able to drop loot without requirements being met.
                // requirements should be checked when equipping the item.
                super._safeTransferFrom(address(this), characters[i], itemIds[i][j], amounts[i][j], "");
                _items[itemIds[i][j]].supplied += amounts[i][j];
            }
        }
        success = true;
    }

    /**
     * @dev this function must be called from the ERC6551 wallet of the player sheet (character account).
     * @param itemId of the item
     * @param amount to claim
     * @param proof allowing this address to claim the item,
     * must be in same order as item ids and amounts
     * if claimable of the item is bytes32(0) the proof can be just an empty array.
     */
    function obtainItems(uint256 itemId, uint256 amount, bytes32[] calldata proof)
        external
        onlyCharacter
        returns (bool success)
    {
        Item storage item = _items[itemId];

        if (item.supply < amount) {
            revert Errors.InventoryError();
        }

        if (item.claimable != bytes32(0)) {
            if (!_verifyMerkle(proof, item.claimable, itemId, amount, msg.sender)) {
                revert Errors.InvalidProof();
            }
            _claimNonce[itemId][msg.sender]++;
        }

        if (item.craftable) {
            return _craftItem(msg.sender, itemId, amount);
        }

        return _claimItem(msg.sender, itemId, amount);
    }

    function dismantleItems(uint256 itemId, uint256 amount) external onlyCharacter returns (bool success) {
        Item storage item = _items[itemId];

        if (!item.craftable) {
            revert Errors.CraftableError();
        }

        // require a successfull dismantle before items can be burnt.
        if (itemsManager.dismantleItems(itemId, amount, msg.sender)) {
            //burn items
            _burn(msg.sender, itemId, amount);

            success = true;
            emit ItemDismantled(msg.sender, itemId, amount);
        } else {
            success = false;
        }
    }

    /**
     * Creates a new type of item
     * @param _itemData the encoded data to create the item struct
     * - bool craftable
     * - bool soulbound_createItem
     * - bytes32 claimable
     * - uint256 supply
     * - string cid
     * - bytes requiredAssets encoded required assets or craft items
     * @return _itemId the ERC1155 tokenId
     */
    function createItemType(bytes calldata _itemData) external onlyGameMaster returns (uint256 _itemId) {
        _itemId = totalItemTypes;

        _createItem(_itemData, _itemId);

        emit NewItemTypeCreated(_itemId);
        emit URI(uri(_itemId), _itemId);

        totalItemTypes++;
        return _itemId;
    }

    /**
     *
     * @param itemId the item id of the item to be updated
     * @param merkleRoot the merkle root of the addresses and amounts that can be claimed of this item
     */
    function updateItemClaimable(uint256 itemId, bytes32 merkleRoot, uint256 newDistribution) external onlyGameMaster {
        if (_items[itemId].supply == 0) {
            revert Errors.ItemError();
        }
        _items[itemId].claimable = merkleRoot;
        _items[itemId].distribution = newDistribution;

        emit ItemClaimableUpdated(itemId, merkleRoot, newDistribution);
    }

    /**
     * @dev Sets `baseURI` as the `_baseURI` for all tokens
     */
    function setBaseURI(string memory _baseUri) external onlyGameMaster {
        _baseURI = _baseUri;
        emit BaseURIUpdated(_baseUri);
    }

    /**
     * @notice this item will delete the Item Struct from the items mapping and burn the remaining supply it will also set the enabled bool to false;
     */
    function deleteItem(uint256 itemId) external onlyGameMaster {
        // cannot delete an Item that has been supplied to anyone.
        if (_items[itemId].supplied != 0) {
            revert Errors.ItemError();
        }

        //burn supply
        _burn(address(this), itemId, _items[itemId].supply);

        // delete stuct from mapping this will set enabled to false.
        delete _items[itemId];

        emit ItemDeleted(itemId);
    }

    /**
     * @dev Sets `tokenURI` as the tokenURI of `tokenId`.
     */
    function setURI(uint256 tokenId, string memory tokenURI) external onlyGameMaster {
        _itemURIs[tokenId] = tokenURI;
        emit URI(uri(tokenId), tokenId);
    }

    /**
     * @dev Sets claim requirements for an item
     */
    function setClaimRequirements(uint256 itemId, bytes memory requiredAssets) external onlyGameMaster {
        // cannot set claim requirements for an item that has been supplied to anyone.
        if (_items[itemId].supplied != 0) {
            revert Errors.ItemError();
        }

        itemsManager.setClaimRequirements(itemId, requiredAssets);
    }

    /**
     * @dev Sets craft requirements for an item
     */
    function setCraftRequirements(uint256 itemId, bytes memory requiredAssets) external onlyGameMaster {
        // cannot set craft requirements for an item that has been supplied to anyone.
        if (_items[itemId].supplied != 0) {
            revert Errors.ItemError();
        }

        itemsManager.setCraftRequirements(itemId, requiredAssets);
    }

    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes memory data)
        public
        override
    {
        if (
            to != address(0) && !IHatsAdaptor(clones.hatsAdaptor()).isCharacter(to)
                && to != address(clones.itemsManager())
        ) {
            revert Errors.CharacterOnly();
        }
        if (_items[id].soulbound) {
            revert Errors.SoulboundToken();
        }
        super.safeTransferFrom(from, to, id, amount, data);
    }

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public override {
        if (to != address(0) && !IHatsAdaptor(clones.hatsAdaptor()).isCharacter(msg.sender)) {
            revert Errors.CharacterOnly();
        }

        for (uint256 i; i < ids.length; i++) {
            if (_items[ids[i]].soulbound) {
                revert Errors.SoulboundToken();
            }
        }
        super.safeBatchTransferFrom(from, to, ids, amounts, data);
    }

    function withdrawAsset(Asset calldata asset, address to) public onlyGameMaster {
        MultiToken.safeTransferAssetFrom(asset, address(this), to);
    }

    function updateItemsManager(address newItemsManager) public onlyGameMaster {
        itemsManager = IItemsManager(newItemsManager);
        emit ItemsManagerUpdated(newItemsManager);
    }

    /**
     * @dev See {IERC1155MetadataURI-uri}.
     *
     * This implementation returns the concatenation of the `_baseURI`
     * and the token-specific uri if the latter is set
     *
     * This enables the following behaviors:
     *
     * with _tokenURI = _itemURIs[_itemId]
     * - if `_tokenURI` is set, then the result is the concatenation
     *   of `_baseURI` and `_tokenURI` (keep in mind that `_baseURI`
     *   is empty per default);
     *
     * - if `_tokenURI` is NOT set then we fallback to `super.uri()`
     *   which in most cases will contain `ERC1155._uri`;
     *
     * - if `_tokenURI` is NOT set, and if the parents do not have a
     *   uri value set, then the result is empty.
     */
    function uri(uint256 _itemId) public view override returns (string memory) {
        string memory _tokenURI = _itemURIs[_itemId];

        // If token URI is set, concatenate base URI and tokenURI (via abi.encodePacked).
        return bytes(_tokenURI).length > 0 ? string(abi.encodePacked(_baseURI, _tokenURI)) : _baseURI;
    }

    function getBaseURI() public view returns (string memory) {
        return _baseURI;
    }

    function getClaimNonce(uint256 itemId, address character) public view returns (uint256) {
        return _claimNonce[itemId][character];
    }

    // The following functions are overrides required by Solidity.

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC1155Upgradeable, ERC1155HolderUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    /// end overrides

    function getItem(uint256 itemId) public view returns (Item memory) {
        return _items[itemId];
    }

    function _createItem(bytes memory _data, uint256 _itemId) internal {
        bool craftable;
        bool soulbound;
        bytes32 claimable;
        uint256 distribution;
        uint256 supply;
        bytes memory requiredAssets;
        string memory cid;
        {
            (craftable, soulbound, claimable, distribution, supply, cid, requiredAssets) =
                abi.decode(_data, (bool, bool, bytes32, uint256, uint256, string, bytes));

            if (craftable) {
                if (requiredAssets.length > 0) {
                    itemsManager.setCraftRequirements(_itemId, requiredAssets);
                } else {
                    revert Errors.CraftableError();
                }
            } else if (requiredAssets.length > 0) {
                itemsManager.setClaimRequirements(_itemId, requiredAssets);
            }

            _items[_itemId] = Item({
                craftable: craftable,
                claimable: claimable,
                distribution: distribution,
                supply: supply,
                soulbound: soulbound,
                supplied: 0,
                enabled: true
            });
            _mint(address(this), _itemId, supply, "");
            _itemURIs[_itemId] = cid;
        }
    }

    function _update(address from, address to, uint256[] memory ids, uint256[] memory values)
        internal
        virtual
        override
    {
        super._update(from, to, ids, values);

        if (to != address(0) && to != address(clones.itemsManager()) && to != address(this)) {
            for (uint256 i; i < ids.length; i++) {
                Item storage item = _items[ids[i]];
                uint256 newBalance = balanceOf(to, ids[i]);
                if (newBalance > item.distribution) {
                    revert Errors.ExceedsDistribution();
                }
            }
        }
    }

    /**
     * transfers an item that has claim requirements.
     * @param character the address of the token bound account of the player nft
     * @param itemId the erc1155 Id of the item to be transfered
     * @param amount the number of items to be transfered
     */
    function _claimItem(address character, uint256 itemId, uint256 amount) internal returns (bool success) {
        if (!itemsManager.checkClaimRequirements(character, itemId)) {
            revert Errors.RequirementNotMet();
        }

        super._safeTransferFrom(address(this), character, itemId, amount, "");
        _items[itemId].supplied += amount;

        emit ItemClaimed(character, itemId, amount);

        success = true;
    }

    /**
     * transfers an item that has craft requirements.
     * @param character the address of the token bound account of the player nft
     * @param itemId the erc1155 Id of the item to be transfered
     * @param amount the number of items to be transfered
     */
    function _craftItem(address character, uint256 itemId, uint256 amount) internal returns (bool success) {
        if (!itemsManager.craftItems(itemId, amount, character)) {
            revert Errors.RequirementNotMet();
        }
        // transfer item after succesful crafting
        super._safeTransferFrom(address(this), msg.sender, itemId, amount, "");
        _items[itemId].supplied += amount;
        emit ItemCrafted(msg.sender, itemId, amount);
        success = true;
    }

    //solhint-disable-next-line
    function _authorizeUpgrade(address newImplementation) internal override onlyGameMaster {
        //empty block
    }

    function _verifyMerkle(bytes32[] memory proof, bytes32 root, uint256 itemId, uint256 amount, address character)
        internal
        view
        returns (bool)
    {
        uint256 nonce = _claimNonce[itemId][character];
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(itemId, msg.sender, nonce, amount))));

        return MerkleProof.verify(proof, root, leaf);
    }
}
