// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Initializable} from "openzeppelin-contracts/proxy/utils/Initializable.sol";
import {MerkleProof} from "openzeppelin-contracts/utils/cryptography/MerkleProof.sol";
import {ERC1155Receiver} from "openzeppelin-contracts/token/ERC1155/utils/ERC1155Receiver.sol";
import {ERC1155, ERC1155TokenReceiver} from "hats-protocol/lib/ERC1155/ERC1155.sol";
import {ERC1155Holder} from "openzeppelin-contracts/token/ERC1155/utils/ERC1155Holder.sol";
import {Counters} from "openzeppelin-contracts/utils/Counters.sol";
// import {console2} from "forge-std/console2.sol";

import {ICharacterSheets} from "../interfaces/ICharacterSheets.sol";
import {ClassesImplementation} from "./ClassesImplementation.sol";
import {ExperienceImplementation} from "./ExperienceImplementation.sol";
import {Item} from "../lib/Structs.sol";
import {Errors} from "../lib/Errors.sol";

/**
 * @title Experience and Items
 * @author MrDeadCe11
 * @notice this is an ERC1155 that is designed to intereact with the characterSheets contract.
 * Each item and class is an 1155 token that can soulbound or not to the erc6551 wallet of each player nft
 * in the characterSheets contract.
 */
contract ItemsImplementation is ERC1155Holder, Initializable, ERC1155 {
    using Counters for Counters.Counter;

    Counters.Counter private _itemIdCounter;

    bytes32 public constant DUNGEON_MASTER = keccak256("DUNGEON_MASTER");
    bytes32 public constant PLAYER = keccak256("PLAYER");
    bytes32 public constant CHARACTER = keccak256("CHARACTER");

    bytes4 private constant _INTERFACE_ID_ERC2981 = 0x2a55205a;

    /// @dev tokenId 0 is reserved for the experience ERC20 contract. if you wish to give or require experience through this contract simply input item ID 0
    /// by a player.
    uint256 public constant EXPERIENCE = 0;

    /// @dev base URI
    string private _baseURI = "";

    /// @dev individual mapping for token URIs
    mapping(uint256 => string) private _itemURIs;

    /// @dev mapping itemId => item struct for item types.;
    mapping(uint256 => Item) public items;

    /// @dev the total number of item types that have been created
    uint256 public totalItemTypes;
    /// @dev the total amount of experience that has been given out
    uint256 public totalExperience;

    /// @dev the interface to the characterSheets erc721 implementation that this is tied to
    ICharacterSheets public characterSheets;
    ClassesImplementation public classes;
    ExperienceImplementation public experience;

    event NewItemTypeCreated(uint256 itemId, string name);
    event ItemTransfered(address character, uint256 itemId, uint256 amount);
    event ItemClaimableUpdated(uint256 itemId, bytes32 merkleRoot);
    event ItemRequirementAdded(uint256 itemId, uint256 requiredItemId, uint256 requiredAmount);
    event ItemRequirementRemoved(uint256 itemId, uint256 requiredItemId);
    event ClassRequirementAdded(uint256 itemId, uint256 requiredClassId);
    event ClassRequirementRemoved(uint256 itemId, uint256 requiredClassId);

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
        address classesAddress;
        address experienceAddress;
        string memory baseUri;
        (characterSheetsAddress, classesAddress, experienceAddress, baseUri) =
            abi.decode(_encodedData, (address, address, address, string));
        _baseURI = baseUri;
        characterSheets = ICharacterSheets(characterSheetsAddress);
        experience = ExperienceImplementation(experienceAddress);
        classes = ClassesImplementation(classesAddress);
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
     * @param nftAddress the tokenbound account of the character CHARACTER to receive the item
     * @param itemIds the item Id's of the loot to be dropped  exp is allways Item Id 0;
     * @param amounts the amounts of each item to be dropped this must be in sync with the item ids
     */

    function dropLoot(address[] calldata nftAddress, uint256[][] calldata itemIds, uint256[][] calldata amounts)
        external
        onlyDungeonMaster
        returns (bool success)
    {
        require(nftAddress.length == itemIds.length && itemIds.length == amounts.length, "LENGTH MISMATCH");
        for (uint256 i; i < nftAddress.length; i++) {
            for (uint256 j; j < itemIds[i].length; j++) {
                if (itemIds[i][j] == 0) {
                    _giveExp(nftAddress[i], amounts[i][j]);
                } else {
                    Item memory newItem = items[itemIds[i][j]];

                    if (newItem.itemRequirements.length > 0 || newItem.classRequirements.length > 0) {
                        _transferItem(nftAddress[i], newItem.tokenId, amounts[i][j]);
                    } else {
                        _transferItemWithReq(nftAddress[i], newItem.tokenId, amounts[i][j]);
                    }
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
                Item memory claimableItem = items[itemIds[i]];
                if (claimableItem.claimable == bytes32(0)) {
                    _transferItemWithReq(msg.sender, claimableItem.tokenId, amounts[i]);
                } else {
                    bytes32 leaf =
                        keccak256(bytes.concat(keccak256(abi.encodePacked(itemIds[i], msg.sender, amounts[i]))));

                    if (!MerkleProof.verify(proofs[i], claimableItem.claimable, leaf)) {
                        revert Errors.InvalidProof();
                    }
                    _transferItemWithReq(msg.sender, claimableItem.tokenId, amounts[i]);
                }
            }
        }
        success = true;
    }
    /**
     * @notice Checks the item and class requirements to create a new item then burns the requirements in the character's inventory to create the new item
     * @dev Explain to a developer any extra details
     * @param itemId the itemId of the item to be crafted
     * @param amount the number of new items to be created
     * @return bool if crafting is a success return true, else return false
     */

    function craftItem(uint256 itemId, uint256 amount) public onlyCharacter returns (bool) {
        Item memory newItem = items[itemId];
        bool success = false;
        if (
            _checkItemRequirements(msg.sender, newItem.itemRequirements, amount)
                && _checkClassRequirements(msg.sender, newItem.classRequirements)
        ) {
            for (uint256 i; i < newItem.itemRequirements.length; i++) {
                if (newItem.itemRequirements[i][0] == 0 && newItem.itemRequirements[i][1] > 0) {
                    experience.burnExp(msg.sender, (newItem.itemRequirements[i][1] * amount));
                } else {
                    _balanceOf[msg.sender][newItem.itemRequirements[i][0]] -= newItem.itemRequirements[i][1] * amount;
                }
            }

            _balanceOf[msg.sender][itemId] += amount;
        } else {
            return success;
        }
        success = true;
        return success;
    }

    /**
     * Creates a new type of item
     * @param itemData the encoded data to create the item struct
     * @return tokenId the ERC1155 tokenId
     */

    function createItemType(bytes calldata itemData) public onlyDungeonMaster returns (uint256 tokenId) {
        Item memory newItem = _createItemStruct(itemData);

        //solhint-disable-next-line
        (bool success,) = address(this).call(abi.encodeWithSignature("findItemByName(string)", newItem.name));

        if (success == true) {
            revert Errors.DuplicateError();
        }
        uint256 _tokenId = _itemIdCounter.current();

        _setURI(_tokenId, newItem.cid);
        _mint(address(this), _tokenId, newItem.supply, bytes(newItem.cid));

        newItem.tokenId = _tokenId;
        items[_tokenId] = newItem;

        emit NewItemTypeCreated(_tokenId, newItem.name);

        _itemIdCounter.increment();

        totalItemTypes++;
        return _tokenId;
    }

    /**
     * adds a new required item to the array of requirments in the item type
     * @param itemId the itemId of the item type to be modified
     * @param requiredItemId the erc1155 token Id of the item to be added to the requirements array
     * @param amount the amount of the required item to be required
     */

    function addItemRequirement(uint256 itemId, uint256 requiredItemId, uint256 amount)
        public
        onlyDungeonMaster
        returns (bool success)
    {
        if (items[requiredItemId].supply == 0) {
            revert Errors.ItemError();
        }
        uint256[] memory newRequirement = new uint256[](2);
        newRequirement[0] = requiredItemId;
        newRequirement[1] = amount;

        items[itemId].itemRequirements.push(newRequirement);
        success = true;

        emit ItemRequirementAdded(itemId, requiredItemId, amount);
        return success;
    }

    function addClassRequirement(uint256 itemId, uint256 requiredClassId)
        public
        onlyDungeonMaster
        returns (bool success)
    {
        if (classes.getClassById(requiredClassId).tokenId == 0) {
            revert Errors.ClassError();
        }
        items[itemId].classRequirements.push(requiredClassId);
        success = true;

        emit ClassRequirementAdded(itemId, requiredClassId);
        return success;
    }

    /**
     *
     * @param itemId the itemId of the item type to be modified
     * @param removedItemId the itemId of the requirement that is to be removed.
     * so if the item requires 2 of itemId 1 to be burnt in order to claim the item then you put in 1
     *  and it will remove the requirment with itemId 1
     */
    function removeItemRequirement(uint256 itemId, uint256 removedItemId) public onlyDungeonMaster returns (bool) {
        uint256[][] memory arr = items[itemId].itemRequirements;
        bool success = false;
        for (uint256 i; i < arr.length; i++) {
            if (arr[i][0] == removedItemId) {
                for (uint256 j = i; j < arr.length; j++) {
                    if (j + 1 < arr.length) {
                        arr[j] = arr[j + 1];
                    } else if (j + 1 >= arr.length) {
                        arr[j] = new uint256[](2);
                    }
                }
                success = true;
            }
        }

        if (success == true) {
            items[itemId].itemRequirements = arr;
            items[itemId].itemRequirements.pop();
        } else {
            revert Errors.ItemError();
        }

        emit ItemRequirementRemoved(itemId, removedItemId);

        return success;
    }

    /**
     * @param itemId the itemId of the item type to be modified
     * @param removedClassId the classId of the requirement that is to be removed.
     */
    function removeClassRequirement(uint256 itemId, uint256 removedClassId) public onlyDungeonMaster returns (bool) {
        uint256[] memory arr = items[itemId].classRequirements;
        bool success = false;
        for (uint256 i; i < arr.length; i++) {
            if (arr[i] == removedClassId) {
                for (uint256 j = i; j < arr.length; j++) {
                    if (j + 1 < arr.length) {
                        arr[j] = arr[j + 1];
                    } else if (j + 1 >= arr.length) {
                        arr[j] = 0;
                    }
                }
                success = true;
            }
        }

        if (success == true) {
            items[itemId].classRequirements = arr;
            items[itemId].classRequirements.pop();
        } else {
            revert Errors.ClassError();
        }

        emit ClassRequirementRemoved(itemId, removedClassId);

        return success;
    }

    /**
     *
     * @param itemId the item id of the item to be updated
     * @param merkleRoot the merkle root of the addresses and amounts that can be claimed of this item
     */

    function updateItemClaimable(uint256 itemId, bytes32 merkleRoot) public onlyDungeonMaster {
        if (items[itemId].tokenId == 0) {
            revert Errors.ItemError();
        }
        items[itemId].claimable = merkleRoot;

        emit ItemClaimableUpdated(itemId, merkleRoot);
    }

    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes calldata data)
        public
        override
    {
        if (!characterSheets.hasRole(CHARACTER, to)) {
            revert Errors.CharacterOnly();
        }
        require(id > 0, "this item does not exist");
        Item memory item = items[id];
        require(item.soulbound == false, "This item is soulbound");
        super.safeTransferFrom(from, to, id, amount, data);
    }

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) public override {
        if (ids.length != amounts.length) {
            revert Errors.LengthMismatch();
        }

        require(msg.sender == from || isApprovedForAll[from][msg.sender], "NOT_AUTHORIZED");

        // Storing these outside the loop saves ~15 gas per iteration.
        uint256 id;
        uint256 amount;

        for (uint256 i = 0; i < ids.length;) {
            safeTransferFrom(from, to, id, amount, data);
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

    function setApprovalForAll(address operator, bool approved) public override {
        super.setApprovalForAll(operator, approved);
    }

    /**
     *
     * @param name a string with the name of the item.  is case sensetive so it is preffered that all names
     * are lowercase alphanumeric names enforced in the frontend.
     * @return tokenId the ERC1155 token id.
     */

    function findItemByName(string memory name) public view returns (uint256 tokenId) {
        string memory temp = name;
        for (uint256 i = 1; i <= totalItemTypes; i++) {
            if (keccak256(abi.encode(items[i].name)) == keccak256(abi.encode(temp))) {
                tokenId = items[i].tokenId;
                return tokenId;
            }
        }
        revert Errors.ItemError();
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

    function supportsInterface(bytes4 interfaceId) public view override(ERC1155Receiver, ERC1155) returns (bool) {
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

    function _createItemStruct(bytes memory data) internal pure returns (Item memory) {
        string memory name;
        uint256 supply;
        uint256[][] memory newItemRequirements;
        uint256[] memory newClassRequirements;
        bool soulbound;
        bytes32 claimable;
        string memory cid;
        {
            (name, supply, newItemRequirements, newClassRequirements, soulbound, claimable, cid) =
                abi.decode(data, (string, uint256, uint256[][], uint256[], bool, bytes32, string));
            return Item(cid, claimable, newClassRequirements, newItemRequirements, name, soulbound, 0, supply, 0);
        }
    }

    /**
     * private function for DM to give out experience.
     * @param _to player nft address
     * @param _amount the amount of exp to be issued
     */

    function _giveExp(address _to, uint256 _amount) private returns (uint256) {
        experience.giveExp(_to, _amount);
        totalExperience += _amount;
        return totalExperience;
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

        if (_balanceOf[address(this)][tokenId] < amount) {
            revert Errors.InsufficientBalance();
        }

        if (tokenId == 0 && amount > 0) {
            _giveExp(_to, amount);
            success = true;
            return success;
        }

        _balanceOf[address(this)][tokenId] -= amount;
        _balanceOf[_to][tokenId] += amount;

        items[tokenId].supplied++;

        emit ItemTransfered(_to, tokenId, amount);
    }

    /**
     * transfers an item that has requirements.
     * @param nftAddress the address of the token bound account of the player nft
     * @param tokenId the erc1155 Id of the item to be transfered
     * @param amount the number of items to be transfered
     */

    function _transferItemWithReq(address nftAddress, uint256 tokenId, uint256 amount) private returns (bool success) {
        if (_balanceOf[address(this)][tokenId] < amount) {
            revert Errors.InsufficientBalance();
        }

        if (!characterSheets.hasRole(CHARACTER, nftAddress)) {
            revert Errors.CharacterOnly();
        }

        if (tokenId == 0 && amount > 0) {
            _giveExp(nftAddress, amount);
            success = true;
            return success;
        }

        Item memory item = items[tokenId];
        if (item.supply == 0) {
            revert Errors.ItemError();
        }

        if (
            _checkItemRequirements(nftAddress, item.itemRequirements, amount)
                && _checkClassRequirements(nftAddress, item.classRequirements)
        ) {
            _balanceOf[address(this)][tokenId] -= amount;
            _balanceOf[nftAddress][tokenId] += amount;
            items[tokenId].supplied += amount;

            emit ItemTransfered(nftAddress, tokenId, amount);

            success = true;
        }

        return success;
    }

    function _checkItemRequirements(address nftAddress, uint256[][] memory itemRequirements, uint256 amount)
        private
        view
        returns (bool)
    {
        if (itemRequirements.length == 0) {
            return true;
        }
        uint256[] memory newRequirement;

        for (uint256 i; i < itemRequirements.length; i++) {
            newRequirement = itemRequirements[i];
            if (newRequirement[0] == 0) {
                if (experience.balanceOf(nftAddress) < newRequirement[1] * amount) {
                    return false;
                }
            } else if (balanceOf(nftAddress, newRequirement[0]) < newRequirement[1] * amount) {
                return false;
            }
        }
        return true;
    }

    function _checkClassRequirements(address nftAddress, uint256[] memory classRequirements)
        private
        view
        returns (bool)
    {
        if (classRequirements.length == 0) {
            return true;
        }
        for (uint256 i; i < classRequirements.length; i++) {
            if (classes.balanceOf(nftAddress, classRequirements[i]) > 0) {
                return true;
            }
        }
        return false;
    }
}
