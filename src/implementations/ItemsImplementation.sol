// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Initializable} from "openzeppelin-contracts/proxy/utils/Initializable.sol";
import {MerkleProof} from "openzeppelin-contracts/utils/cryptography/MerkleProof.sol";
import {ERC1155Upgradeable} from "openzeppelin-contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import {
    ERC1155HolderUpgradeable,
    ERC1155ReceiverUpgradeable
} from "openzeppelin-contracts-upgradeable/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";
import {UUPSUpgradeable} from "openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Counters} from "openzeppelin-contracts/utils/Counters.sol";
// import {console2} from "forge-std/console2.sol";

import {ICharacterSheets} from "../interfaces/ICharacterSheets.sol";
import {ClassesImplementation} from "./ClassesImplementation.sol";
import {ExperienceImplementation} from "./ExperienceImplementation.sol";
import {Item} from "../lib/Structs.sol";
import {Errors} from "../lib/Errors.sol";
import {MultiToken, Asset, Category} from "../lib/MultiToken.sol";

/**
 * @title Experience and Items
 * @author MrDeadCe11
 * @notice this is an ERC1155 that is designed to intereact with the characterSheets contract.
 * Each item and class is an 1155 token that can soulbound or not to the erc6551 wallet of each player nft
 * in the characterSheets contract.
 */
contract ItemsImplementation is ERC1155HolderUpgradeable, ERC1155Upgradeable, UUPSUpgradeable {
    using Counters for Counters.Counter;

    Counters.Counter private _itemIdCounter;

    bytes32 public constant DUNGEON_MASTER = keccak256("DUNGEON_MASTER");
    bytes32 public constant CHARACTER = keccak256("CHARACTER");

    bytes4 private constant _INTERFACE_ID_ERC2981 = 0x2a55205a;

    /// @dev base URI
    string private _baseURI = "";

    /// @dev individual mapping for token URIs
    mapping(uint256 => string) private _itemURIs;

    /// @dev mapping itemId => item struct for item types.;
    mapping(uint256 => Item) public items;
    /// @dev an array of requirements to transfer this item
    mapping(uint256 => Asset[]) public requirements;

    /// @dev the total number of item types that have been created
    uint256 public totalItemTypes;

    /// @dev the interface to the characterSheets erc721 implementation that this is tied to
    ICharacterSheets public characterSheets;

    event NewItemTypeCreated(uint256 itemId);
    event ItemTransfered(address character, uint256 itemId, uint256 amount);
    event ItemClaimableUpdated(uint256 itemId, bytes32 merkleRoot);
    event RequirementAdded(uint256 itemId, uint8 category, address assetAddress, uint256 assetId, uint256 amount);
    event RequirementRemoved(uint256 itemId, address assetAddress, uint256 assetId);

    modifier onlyDungeonMaster() {
        if (!characterSheets.hasRole(DUNGEON_MASTER, msg.sender)) {
            revert Errors.DungeonMasterOnly();
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
        __UUPSUpgradeable_init();
        __ERC1155Holder_init();

        address characterSheetsAddress;
        string memory baseUri;
        (characterSheetsAddress, baseUri) = abi.decode(_encodedData, (address, string));
        _baseURI = baseUri;
        characterSheets = ICharacterSheets(characterSheetsAddress);

        _itemIdCounter.increment();
    }

    function batchCreateItemType(bytes[] calldata itemDatas)
        external
        onlyDungeonMaster
        returns (uint256[] memory tokenIds)
    {
        tokenIds = new uint256[](itemDatas.length);

        for (uint256 i; i < itemDatas.length; i++) {
            tokenIds[i] = createItemType(itemDatas[i]);
        }
    }

    /**
     * drops loot and/or exp after a completed quest items dropped through dropLoot do cost exp.
     * @param characterAccounts the tokenbound accounts of the character CHARACTER to receive the item
     * @param itemIds the item Id's of the loot to be dropped  exp is allways Item Id 0;
     * @param amounts the amounts of each item to be dropped this must be in sync with the item ids
     */

    function dropLoot(address[] calldata characterAccounts, uint256[][] calldata itemIds, uint256[][] calldata amounts)
        external
        onlyDungeonMaster
        returns (bool success)
    {
        require(characterAccounts.length == itemIds.length && itemIds.length == amounts.length, "LENGTH MISMATCH");
        for (uint256 i; i < characterAccounts.length; i++) {
            for (uint256 j; j < itemIds[i].length; j++) {
                if (requirements[itemIds[i][j]].length == 0) {
                    _transferItem(characterAccounts[i], itemIds[i][j], amounts[i][j]);
                } else {
                    _transferItemWithReq(characterAccounts[i], itemIds[i][j], amounts[i][j]);
                }
            }
        }
        success = true;
    }

    /**
     * this is to be claimed from the ERC6551 wallet of the player sheet.
     * @param itemIds an array of item ids
     * @param amounts an array of amounts to claim, must match the order of item ids
     * @param proofs an array of proofs allowing this address to claim the item,
     * must be in same order as item ids and amounts
     */

    function claimItems(uint256[] calldata itemIds, uint256[] calldata amounts, bytes32[][] calldata proofs)
        external
        onlyCharacter
        returns (bool success)
    {
        if (itemIds.length != amounts.length || itemIds.length != proofs.length) {
            revert Errors.LengthMismatch();
        }

        for (uint256 i = 0; i < itemIds.length; i++) {
            if (itemIds[i] == 0) {
                revert Errors.ItemError();
            } else {
                Item storage claimableItem = items[itemIds[i]];
                if (claimableItem.claimable == bytes32(0)) {
                    _transferItemWithReq(msg.sender, itemIds[i], amounts[i]);
                } else {
                    bytes32 leaf =
                        keccak256(bytes.concat(keccak256(abi.encodePacked(itemIds[i], msg.sender, amounts[i]))));

                    if (!MerkleProof.verify(proofs[i], claimableItem.claimable, leaf)) {
                        revert Errors.InvalidProof();
                    }
                    _transferItemWithReq(msg.sender, itemIds[i], amounts[i]);
                }
            }
        }
        success = true;
    }

    /**
     * @notice Checks the item requirements to create a new item then burns the requirements in the character's inventory to create the new item
     * @dev Explain to a developer any extra details
     * @param itemId the itemId of the item to be crafted
     * @param amount the number of new items to be created
     * @return success bool if crafting is a success return true, else return false
     */

    function craftItem(uint256 itemId, uint256 amount) public onlyCharacter returns (bool success) {
        Item storage newItem = items[itemId];

        if (!newItem.craftable) {
            revert Errors.ItemError();
        }

        Asset[] storage itemRequirements = requirements[itemId];

        if (!_checkRequirements(msg.sender, itemRequirements, amount)) {
            revert Errors.RequirementNotMet();
        }

        for (uint256 i; i < itemRequirements.length; i++) {
            Asset storage newRequirement = itemRequirements[i];
            newRequirement.amount = newRequirement.amount * amount;
            if (newRequirement.assetAddress == address(this)) {
                _burn(msg.sender, newRequirement.id, newRequirement.amount);
            } else {
                MultiToken.safeTransferAssetFrom(newRequirement, msg.sender, address(0));
            }
        }

        _transferItem(msg.sender, itemId, amount);
        success = true;
        return success;
    }

    /**
     * Creates a new type of item
     * @param _itemData the encoded data to create the item struct
     * @return _tokenId the ERC1155 tokenId
     */

    function createItemType(bytes calldata _itemData) public onlyDungeonMaster returns (uint256 _tokenId) {
        _tokenId = _itemIdCounter.current();

        _createItem(_itemData, _tokenId);

        emit NewItemTypeCreated(_tokenId);

        _itemIdCounter.increment();

        totalItemTypes++;
        return _tokenId;
    }

    /**
     * adds a new required item to the array of requirments in the item type
     * @param itemId the itemId of the item type to be modified
     * @param category the category of the required item
     * @param assetAddress the address of the required item
     * @param assetId the id of the required item
     * @param amount the amount of the required item to be required
     */

    function addItemRequirement(uint256 itemId, uint8 category, address assetAddress, uint256 assetId, uint256 amount)
        public
        onlyDungeonMaster
        returns (bool success)
    {
        if (assetAddress == address(this) && (itemId == assetId || (items[assetId].supply == 0))) {
            revert Errors.ItemError();
        }
        Asset memory newRequirement =
            Asset({category: Category(category), assetAddress: assetAddress, id: assetId, amount: amount});

        requirements[itemId].push(newRequirement);
        success = true;

        emit RequirementAdded(itemId, category, assetAddress, assetId, amount);
        return success;
    }

    /**
     *
     * @param itemId the itemId of the item type to be modified
     * @param assetAddress the address of the required item
     * @param assetId the id of the required item
     * so if the item requires 2 of itemId 1 to be burnt in order to claim the item then you put in 1
     *  and it will remove the requirment with itemId 1
     */
    function removeItemRequirement(uint256 itemId, address assetAddress, uint256 assetId)
        public
        onlyDungeonMaster
        returns (bool)
    {
        Asset[] storage arr = requirements[itemId];
        bool success = false;
        for (uint256 i; i < arr.length; i++) {
            Asset storage asset = arr[i];
            if (asset.assetAddress == assetAddress && asset.id == assetId) {
                for (uint256 j = i; j < arr.length; j++) {
                    if (j + 1 < arr.length) {
                        arr[j] = arr[j + 1];
                    } else if (j + 1 >= arr.length) {
                        arr[j] = MultiToken.ERC20(address(0), 0);
                    }
                }
                success = true;
            }
        }

        if (success == true) {
            requirements[itemId] = arr;
            requirements[itemId].pop();
        } else {
            revert Errors.ItemError();
        }

        emit RequirementRemoved(itemId, assetAddress, assetId);

        return success;
    }

    /**
     *
     * @param itemId the item id of the item to be updated
     * @param merkleRoot the merkle root of the addresses and amounts that can be claimed of this item
     */

    function updateItemClaimable(uint256 itemId, bytes32 merkleRoot) public onlyDungeonMaster {
        if (items[itemId].supply == 0) {
            // tokenId 0 has supply 0
            revert Errors.ItemError();
        }
        items[itemId].claimable = merkleRoot;

        emit ItemClaimableUpdated(itemId, merkleRoot);
    }

    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes memory data)
        public
        override
    {
        if (to != address(0) && !characterSheets.hasRole(CHARACTER, to)) {
            revert Errors.CharacterOnly();
        }
        if (items[id].supply == 0) {
            // tokenId 0 has supply 0
            revert Errors.InvalidToken();
        }
        if (items[id].soulbound) {
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
        if (!characterSheets.hasRole(CHARACTER, to)) {
            revert Errors.CharacterOnly();
        }

        for (uint256 i; i < ids.length; i++) {
            if (items[ids[i]].supply == 0) {
                // tokenId 0 has supply 0
                revert Errors.InvalidToken();
            }
            if (items[ids[i]].soulbound) {
                revert Errors.SoulboundToken();
            }
        }
        super.safeBatchTransferFrom(from, to, ids, amounts, data);
    }

    /**
     * returns an array of all Item structs in the Item's mapping
     */
    function getAllItems() public view returns (Item[] memory) {
        Item[] memory allItems = new Item[](totalItemTypes);
        for (uint256 i = 0; i <= totalItemTypes; i++) {
            allItems[i] = items[i];
        }
        return allItems;
    }

    function getItemById(uint256 itemId) public view returns (Item memory) {
        return items[itemId];
    }

    /**
     * @dev See {IERC1155MetadataURI-uri}.
     *
     * This implementation returns the concatenation of the `_baseURI`
     * and the token-specific uri if the latter is set
     *
     * This enables the following behaviors:
     *
     * - if `_itemURIs[tokenId]` is set, then the result is the concatenation
     *   of `_baseURI` and `_itemURIs[tokenId]` (keep in mind that `_baseURI`
     *   is empty per default);
     *
     * - if `_itemURIs[tokenId]` is NOT set then we fallback to `super.uri()`
     *   which in most cases will contain `ERC1155._uri`;
     *
     * - if `_itemURIs[tokenId]` is NOT set, and if the parents do not have a
     *   uri value set, then the result is empty.
     */

    function uri(uint256 tokenId) public view override returns (string memory) {
        string memory tokenURI = _itemURIs[tokenId];

        // If token URI is set, concatenate base URI and tokenURI (via abi.encodePacked).
        return bytes(tokenURI).length > 0 ? string(abi.encodePacked(_baseURI, tokenURI)) : _baseURI;
    }

    function getBaseURI() public view returns (string memory) {
        return _baseURI;
    }

    // The following functions are overrides required by Solidity.

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC1155Upgradeable, ERC1155ReceiverUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    /// end overrides

    /**
     * @dev Sets `tokenURI` as the tokenURI of `tokenId`.
     */

    function _setURI(uint256 tokenId, string memory tokenURI) internal {
        _itemURIs[tokenId] = tokenURI;
        emit URI(uri(tokenId), tokenId);
    }

    /**
     * @dev Sets `baseURI` as the `_baseURI` for all tokens
     */

    function _setBaseURI(string memory _baseUri) internal {
        _baseURI = _baseUri;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyDungeonMaster {}

    function _createItem(bytes memory _data, uint256 _tokenId) internal {
        bool craftable;
        bool soulbound;
        bytes32 claimable;
        uint256 supply;
        bytes memory requiredAssets;
        string memory cid;
        {
            (craftable, soulbound, claimable, supply, cid, requiredAssets) =
                abi.decode(_data, (bool, bool, bytes32, uint256, string, bytes));

            {
                uint8[] memory requiredAssetCategories;
                address[] memory requiredAssetAddresses;
                uint256[] memory requiredAssetIds;
                uint256[] memory requiredAssetAmounts;

                {
                    (requiredAssetCategories, requiredAssetAddresses, requiredAssetIds, requiredAssetAmounts) =
                        abi.decode(requiredAssets, (uint8[], address[], uint256[], uint256[]));

                    if (
                        requiredAssetCategories.length != requiredAssetAddresses.length
                            || requiredAssetAddresses.length != requiredAssetIds.length
                            || requiredAssetIds.length != requiredAssetAmounts.length
                    ) {
                        revert Errors.LengthMismatch();
                    }

                    Asset[] storage itemRequirements = requirements[_tokenId];

                    for (uint256 i = 0; i < requiredAssetAddresses.length; i++) {
                        itemRequirements[i] = Asset({
                            category: Category(requiredAssetCategories[i]),
                            assetAddress: requiredAssetAddresses[i],
                            id: requiredAssetIds[i],
                            amount: requiredAssetAmounts[i]
                        });
                    }
                }
            }

            items[_tokenId] =
                Item({craftable: craftable, claimable: claimable, supply: supply, soulbound: soulbound, supplied: 0});
            _setURI(_tokenId, cid);
            _mint(address(this), _tokenId, supply, "");
        }
    }

    /**
     * internal function to transfer items.
     * @param _to the token bound account to receive the item;
     * @param tokenId the erc1155 id of the Item in the items mapping.
     * @param amount the amount of items to be sent to the player token
     */

    function _transferItem(address _to, uint256 tokenId, uint256 amount) private returns (bool success) {
        if (!characterSheets.hasRole(CHARACTER, _to)) {
            revert Errors.CharacterOnly();
        }

        Item storage item = items[tokenId];
        if (item.supply == 0) {
            revert Errors.ItemError();
        }

        super._safeTransferFrom(address(this), _to, tokenId, amount, "");

        items[tokenId].supplied++;

        success = true;

        emit ItemTransfered(_to, tokenId, amount);
    }

    /**
     * transfers an item that has requirements.
     * @param characterAccount the address of the token bound account of the player nft
     * @param tokenId the erc1155 Id of the item to be transfered
     * @param amount the number of items to be transfered
     */

    function _transferItemWithReq(address characterAccount, uint256 tokenId, uint256 amount)
        private
        returns (bool success)
    {
        if (!characterSheets.hasRole(CHARACTER, characterAccount)) {
            revert Errors.CharacterOnly();
        }

        Item storage item = items[tokenId];
        if (item.supply == 0) {
            revert Errors.ItemError();
        }

        if (!_checkRequirements(characterAccount, requirements[tokenId], amount)) {
            revert Errors.RequirementNotMet();
        }

        super._safeTransferFrom(address(this), characterAccount, tokenId, amount, "");
        items[tokenId].supplied += amount;

        emit ItemTransfered(characterAccount, tokenId, amount);

        success = true;

        return success;
    }

    function _checkRequirements(address characterAccount, Asset[] storage itemRequirements, uint256 amount)
        private
        view
        returns (bool)
    {
        if (itemRequirements.length == 0) {
            return true;
        }
        Asset storage newRequirement;

        for (uint256 i; i < itemRequirements.length; i++) {
            newRequirement = itemRequirements[i];
            uint256 balance = MultiToken.balanceOf(newRequirement, characterAccount);

            if (balance < newRequirement.amount * amount) {
                return false;
            }
        }
        return true;
    }
}
