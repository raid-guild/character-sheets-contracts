// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {MerkleProof} from "openzeppelin-contracts/utils/cryptography/MerkleProof.sol";
import {ERC1155Upgradeable} from "openzeppelin-contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import {
    ERC1155HolderUpgradeable,
    ERC1155ReceiverUpgradeable
} from "openzeppelin-contracts-upgradeable/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";
import {
    ERC721HolderUpgradeable,
    IERC721ReceiverUpgradeable
} from "openzeppelin-contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import {UUPSUpgradeable} from "openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {Item} from "../lib/Structs.sol";
import {Errors} from "../lib/Errors.sol";
import {MultiToken, Asset, Category} from "../lib/MultiToken.sol";
import "../lib/Structs.sol";

import {IItems} from "../interfaces/IItems.sol";
import {IHatsAdaptor} from "../interfaces/IHatsAdaptor.sol";

import "forge-std/console2.sol";
/**
 * @title Experience and Items
 * @author MrDeadCe11 && dan13ram
 * @notice this is an ERC1155 that is designed to intereact with the characterSheets contract.
 * Each item and class is an 1155 token that can soulbound or not to the erc6551 wallet of each player nft
 * in the characterSheets contract.
 */

contract ItemsImplementation is
    IItems,
    ERC1155HolderUpgradeable,
    ERC1155Upgradeable,
    ERC721HolderUpgradeable,
    UUPSUpgradeable
{
    bytes32 public constant DUNGEON_MASTER = keccak256("DUNGEON_MASTER");
    bytes32 public constant CHARACTER = keccak256("CHARACTER");

    bytes4 private constant _INTERFACE_ID_ERC2981 = 0x2a55205a;

    /// @dev base URI
    string private _baseURI = "";

    /// @dev mapping itemId => uris for metadata
    mapping(uint256 => string) private _itemURIs;
    /// @dev mapping itemId => item struct for item types
    mapping(uint256 => Item) private _items;
    /// @dev an array of requirements to transfer this item
    mapping(uint256 => Asset[]) private _requirements;
    /// @dev stores the items used in crafting at the time the item was crafted.
    /// character => itemId => receipts Assets used in crafting
    mapping(address => mapping(uint256 => Receipt[])) private _craftingReceipt;

    /// @dev the total number of item types that have been created
    uint256 public totalItemTypes;

    /// @dev the interface to the characterSheets erc721 implementation that this is tied to
    address public hatsAdaptor;

    /// @dev address of the classes contract for item requirements check
    address public classesContract;

    event NewItemTypeCreated(uint256 itemId);
    event ItemTransfered(address character, uint256 itemId, uint256 amount);
    event ItemClaimableUpdated(uint256 itemId, bytes32 merkleRoot);
    event RequirementAdded(uint256 itemId, uint8 category, address assetAddress, uint256 assetId, uint256 amount);
    event RequirementRemoved(uint256 itemId, address assetAddress, uint256 assetId);

    modifier onlyDungeonMaster() {
        if (!IHatsAdaptor(hatsAdaptor).isDungeonMaster(msg.sender)) {
            revert Errors.DungeonMasterOnly();
        }
        _;
    }

    modifier onlyCharacter() {
        if (!IHatsAdaptor(hatsAdaptor).isCharacter(msg.sender)) {
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

        (hatsAdaptor, classesContract, _baseURI) = abi.decode(_encodedData, (address, address, string));
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
        if (characterAccounts.length != itemIds.length || itemIds.length != amounts.length) {
            revert Errors.LengthMismatch();
        }
        for (uint256 i; i < characterAccounts.length; i++) {
            for (uint256 j; j < itemIds[i].length; j++) {
                // dm should be able to drop loot without requirements being met.
                // requirements should be checked when equipping the item.
                super._safeTransferFrom(address(this), characterAccounts[i], itemIds[i][j], amounts[i][j], "");
                _items[itemIds[i][j]].supplied += amounts[i][j];
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
            Item storage claimableItem = _items[itemIds[i]];
            // if item is craftable this item must be claimed by calling the (craftItem) function
            if (claimableItem.craftable) {
                revert Errors.ClaimableError();
            }
            if (claimableItem.claimable == bytes32(0)) {
                _transferItem(msg.sender, itemIds[i], amounts[i]);
            } else {
                bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encodePacked(itemIds[i], msg.sender, amounts[i]))));

                if (!MerkleProof.verify(proofs[i], claimableItem.claimable, leaf)) {
                    revert Errors.InvalidProof();
                }
                _transferItem(msg.sender, itemIds[i], amounts[i]);
            }
        }
        success = true;
    }

    /**
     * @notice Checks the item requirements to create a new item then transfers the requirements in the character's inventory to this contract to create the new item
     * @dev Explain to a developer any extra details
     * @param itemId the itemId of the item to be crafted
     * @param amount the number of new items to be created
     * @return success bool if crafting is a success return true, else return false
     */

    function craftItem(uint256 itemId, uint256 amount) external onlyCharacter returns (bool success) {
        Item storage newItem = _items[itemId];

        if (!newItem.craftable) {
            revert Errors.ItemError();
        }

        if (!_checkRequirements(msg.sender, itemId, amount)) {
            revert Errors.RequirementNotMet();
        }

        Asset[] storage itemRequirements = _requirements[itemId];

        for (uint256 i; i < itemRequirements.length; i++) {
            Asset memory newRequirement = itemRequirements[i];
            //if required item is not a class
            if (newRequirement.assetAddress != classesContract) {
                //issue crafting receipt before amounts change
                _craftingReceipt[msg.sender][itemId].push(
                    Receipt({
                        category: newRequirement.category,
                        assetAddress: newRequirement.assetAddress,
                        assetId: newRequirement.id,
                        amountCrafted: amount,
                        amountRequired: newRequirement.amount
                    })
                );

                //add asset amounts
                newRequirement.amount = newRequirement.amount * amount;

                //transfer assets to this contract must have approval
                MultiToken.safeTransferAssetFrom(newRequirement, msg.sender, address(this));

                // TODO create a dismatle function that returns the items to the player
            }
        }

        super._safeTransferFrom(address(this), msg.sender, itemId, amount, "");
        success = true;
        return success;
    }

    Asset[] private currentRefunds;

    function dismantleItems(uint256 itemId, uint256 amount) external onlyCharacter returns (bool succes) {
        //check crafted items array if any assets exist
        if (_craftingReceipt[msg.sender][itemId].length == 0) {
            revert Errors.ItemError();
        }
        if (balanceOf(msg.sender, itemId) < amount) {
            revert Errors.InsufficientBalance();
        }

        for (uint256 i = _craftingReceipt[msg.sender][itemId].length; i > 0; i--) {
            // remaing number of items to dismantle
            uint256 remainingAmount = amount;
            //calculate refunds
            while (remainingAmount > 0) {
                Asset memory refund;
                uint256 remainder;
                (remainder, refund) = _calculateRefund(msg.sender, itemId, remainingAmount);
                remainingAmount = remainder;
                // // add refund to refunds array
                currentRefunds.push(refund);
            }
        }
        /// refund assets
        for (uint256 i; i < currentRefunds.length; i++) {
            console2.log(currentRefunds[i].amount);
            MultiToken.safeTransferAssetFrom(currentRefunds[i], address(this), msg.sender);
        }

        //burn items
        _burn(msg.sender, itemId, amount);

        //clear refunds
        delete currentRefunds;

        return true;
    }

    function _calculateRefund(address to, uint256 itemId, uint256 amount)
        private
        returns (uint256 remainder, Asset memory refund)
    {
        //get last receipt in array
        Receipt memory latestReceipt = _craftingReceipt[to][itemId][_craftingReceipt[to][itemId].length - 1];

        remainder = amount;

        //if amount > crafted amounts remainder = amount - crafted amounts
        if (amount < latestReceipt.amountCrafted) {
            remainder = 0;
            refund = Asset({
                category: latestReceipt.category,
                assetAddress: latestReceipt.assetAddress,
                id: itemId,
                amount: amount * latestReceipt.amountRequired
            });
            latestReceipt.amountCrafted -= amount;
            _craftingReceipt[to][itemId][_craftingReceipt[to][itemId].length - 1] = latestReceipt;
        } else if (amount == latestReceipt.amountCrafted) {
            remainder += 0;
            refund = Asset({
                category: latestReceipt.category,
                assetAddress: latestReceipt.assetAddress,
                id: itemId,
                amount: latestReceipt.amountCrafted * latestReceipt.amountRequired
            });
            _craftingReceipt[to][itemId].pop();
        } else {
            refund = Asset({
                category: latestReceipt.category,
                assetAddress: latestReceipt.assetAddress,
                id: itemId,
                amount: latestReceipt.amountCrafted * latestReceipt.amountRequired
            });

            remainder -= latestReceipt.amountCrafted;
            _craftingReceipt[to][itemId].pop();
        }

        return (remainder, refund);
    }

    /**
     * Creates a new type of item
     * @param _itemData the encoded data to create the item struct
     * - bool craftable
     * - bool soulbound_createItem
     * - bytes32 claimable
     * - uint256 supply
     * - string cid
     * - bytes requiredAssets encoded required assets,
     *             - uint8[] memory requiredAssetCategories;
     *             - address[] memory requiredAssetAddresses;
     *             - uint256[] memory requiredAssetIds;
     *             - uint256[] memory requiredAssetAmounts;
     * @return _itemId the ERC1155 tokenId
     */

    function createItemType(bytes calldata _itemData) external onlyDungeonMaster returns (uint256 _itemId) {
        _itemId = totalItemTypes;

        _createItem(_itemData, _itemId);

        emit NewItemTypeCreated(_itemId);
        emit URI(uri(_itemId), _itemId);

        totalItemTypes++;
        return _itemId;
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
        external
        onlyDungeonMaster
        returns (bool success)
    {
        if (assetAddress == address(this) && (itemId == assetId || (_items[assetId].supply == 0))) {
            revert Errors.ItemError();
        }
        Asset memory newRequirement =
            Asset({category: Category(category), assetAddress: assetAddress, id: assetId, amount: amount});

        _requirements[itemId].push(newRequirement);
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
        external
        onlyDungeonMaster
        returns (bool)
    {
        Asset[] storage arr = _requirements[itemId];
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
            _requirements[itemId] = arr;
            _requirements[itemId].pop();
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

    function updateItemClaimable(uint256 itemId, bytes32 merkleRoot) external onlyDungeonMaster {
        if (_items[itemId].supply == 0) {
            revert Errors.ItemError();
        }
        _items[itemId].claimable = merkleRoot;

        emit ItemClaimableUpdated(itemId, merkleRoot);
    }

    /**
     * @dev Sets `baseURI` as the `_baseURI` for all tokens
     */
    function setBaseURI(string memory _baseUri) external onlyDungeonMaster {
        _baseURI = _baseUri;
        // TODO: add event
    }

    /**
     * @dev Sets `tokenURI` as the tokenURI of `tokenId`.
     */

    function setURI(uint256 tokenId, string memory tokenURI) external onlyDungeonMaster {
        _itemURIs[tokenId] = tokenURI;
        emit URI(uri(tokenId), tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes memory data)
        public
        override
    {
        if (to != address(0) && !IHatsAdaptor(hatsAdaptor).isCharacter(msg.sender)) {
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
        if (to != address(0) && !IHatsAdaptor(hatsAdaptor).isCharacter(msg.sender)) {
            revert Errors.CharacterOnly();
        }

        for (uint256 i; i < ids.length; i++) {
            if (_items[ids[i]].soulbound) {
                revert Errors.SoulboundToken();
            }
        }
        super.safeBatchTransferFrom(from, to, ids, amounts, data);
    }

    function withdrawAsset(Asset calldata asset, address to) public onlyDungeonMaster {
        MultiToken.safeTransferAssetFrom(asset, address(this), to);
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

    // The following functions are overrides required by Solidity.

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC1155Upgradeable, ERC1155ReceiverUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function getItem(uint256 itemId) public view returns (Item memory) {
        return _items[itemId];
    }

    function getItemRequirements(uint256 itemId) public view returns (Asset[] memory) {
        return _requirements[itemId];
    }

    /// end overrides

    function _createItem(bytes memory _data, uint256 _itemId) internal {
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

                    Asset[] storage itemRequirements = _requirements[_itemId];

                    for (uint256 i = 0; i < requiredAssetAddresses.length; i++) {
                        itemRequirements.push(
                            Asset({
                                category: Category(requiredAssetCategories[i]),
                                assetAddress: requiredAssetAddresses[i],
                                id: requiredAssetIds[i],
                                amount: requiredAssetAmounts[i]
                            })
                        );
                    }
                }
            }

            _items[_itemId] =
                Item({craftable: craftable, claimable: claimable, supply: supply, soulbound: soulbound, supplied: 0});
            _mint(address(this), _itemId, supply, "");
            _itemURIs[_itemId] = cid;
        }
    }

    /**
     * transfers an item that has requirements.
     * @param characterAccount the address of the token bound account of the player nft
     * @param itemId the erc1155 Id of the item to be transfered
     * @param amount the number of items to be transfered
     */

    function _transferItem(address characterAccount, uint256 itemId, uint256 amount) internal returns (bool success) {
        if (!IHatsAdaptor(hatsAdaptor).isCharacter(characterAccount)) {
            revert Errors.CharacterOnly();
        }

        Item storage item = _items[itemId];
        if (item.supply == 0) {
            revert Errors.ItemError();
        }

        if (!_checkRequirements(characterAccount, itemId, amount)) {
            revert Errors.RequirementNotMet();
        }

        super._safeTransferFrom(address(this), characterAccount, itemId, amount, "");
        _items[itemId].supplied += amount;

        emit ItemTransfered(characterAccount, itemId, amount);

        success = true;

        return success;
    }

    //solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address newImplementation) internal override onlyDungeonMaster {}

    function _checkRequirements(address characterAccount, uint256 itemId, uint256 amount)
        internal
        view
        returns (bool)
    {
        Asset[] storage itemRequirements = _requirements[itemId];
        if (itemRequirements.length == 0) {
            return true;
        }

        Asset storage newRequirement;

        for (uint256 i; i < itemRequirements.length; i++) {
            newRequirement = itemRequirements[i];

            uint256 balance = MultiToken.balanceOf(newRequirement, characterAccount);

            // if the required asset is a class check that the balance is not less than the required level.
            if (newRequirement.assetAddress == classesContract) {
                if (balance < newRequirement.amount) {
                    return false;
                }
            } else if (balance < newRequirement.amount * amount) {
                return false;
            }
        }
        return true;
    }
}
