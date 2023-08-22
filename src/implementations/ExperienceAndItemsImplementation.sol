// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {MerkleProof} from "openzeppelin/utils/cryptography/MerkleProof.sol";
import {Strings} from "openzeppelin/utils/Strings.sol";
import {ERC1155Receiver} from "openzeppelin/token/ERC1155/utils/ERC1155Receiver.sol";
import {ERC1155, ERC1155TokenReceiver} from "hats-protocol/lib/ERC1155/ERC1155.sol";
import {IHats} from "hats-protocol/src/Interfaces/IHats.sol";
import {IERC721} from "openzeppelin/token/ERC721/IERC721.sol";
import {ERC1155Holder} from "openzeppelin/token/ERC1155/utils/ERC1155Holder.sol";
import {Counters} from "openzeppelin/utils/Counters.sol";

import {CharacterSheetsImplementation} from "../implementations/CharacterSheetsImplementation.sol";
import {IMolochDAO} from "../interfaces/IMolochDAO.sol";
import {Item, Class, CharacterSheet} from "../lib/Structs.sol";

//solhint-disable-next-line
import "../lib/Errors.sol";

/**
 * @title Experience and Items
 * @author MrDeadCe11
 * @notice this is an ERC1155 that is designed to intereact with the characterSheets contract.
 * Each item and class is an 1155 token that can soulbound or not to the erc6551 wallet of each player nft
 * in the characterSheets contract.
 */
contract ExperienceAndItemsImplementation is ERC1155Holder, Initializable, ERC1155 {
    using Strings for uint256;
    using Counters for Counters.Counter;

    Counters.Counter private _itemsCounter;
    Counters.Counter private _classesCounter;
    Counters.Counter private _tokenIdCounter;

    bytes32 public constant DUNGEON_MASTER = keccak256("DUNGEON_MASTER");
    bytes32 public constant PLAYER = keccak256("PLAYER");
    bytes32 public constant CHARACTER = keccak256("CHARACTER");

    bytes4 private constant _INTERFACE_ID_ERC2981 = 0x2a55205a;

    /// @dev base URI
    string private _baseURI = "";

    /// @dev individual mapping for token URIs
    mapping(uint256 => string) private _tokenURIs;

    /// @dev mapping itemId => item struct for item types.;
    mapping(uint256 => Item) public items;
    /// @dev mapping of class token types.  the class Id is the location in this mapping of the class.
    mapping(uint256 => Class) public classes;
    /// @dev mapping of the erc1155 tokenId to the itemID.  if the 1155 token is a class it will not be in this mapping.
    mapping(uint256 => uint256) internal _tokenIdToItemId;
    /// @dev mapping of erc1155 tokenID of a class to the class Id;
    mapping(uint256 => uint256) internal _tokenIdToClassId;
    /// @dev tokenId 0 is experience which is infinite supply and can be minted by any dungeon master or claimed
    /// by a player.
    uint256 public constant EXPERIENCE = 0;
    /// @dev the total number of class types that have been created
    uint256 public totalClasses;
    /// @dev the total number of item types that have been created
    uint256 public totalItemTypes;
    /// @dev the total amount of experience that has been given out
    uint256 public totalExperience;

    /// @dev the interface for the molochDao who's members are allowed character sheets
    IMolochDAO public molochDao;
    /// @dev the interface to the characterSheets erc721 implementation that this is tied to
    CharacterSheetsImplementation public characterSheets;
    IHats public hats; // not implemented

    event NewItemTypeCreated(uint256 erc1155TokenId, uint256 itemId, string name);
    event NewClassCreated(uint256 erc1155TokenId, uint256 classId, string name);
    event ClassAssigned(address classAssignedTo, uint256 erc1155TokenId, uint256 classId);
    event ItemTransfered(address itemTransferedTo, uint256 erc1155TokenId, uint256 itemId);
    event ItemUpdated(uint256 itemId);

    modifier onlyDungeonMaster() {
        if(!characterSheets.hasRole(DUNGEON_MASTER, msg.sender)){
            revert Errors.DungeonMasterOnly();
        }
        _;
    }

    modifier onlyPlayer() {
        if(!characterSheets.hasRole(PLAYER, msg.sender)){
            revert Errors.PlayerOnly();
        }
        _;
    }

    modifier onlyCharacter() {
        if(!characterSheets.hasRole(CHARACTER, msg.sender)){
            revert Errors.CharacterOnly();
        }
        _;
    }

    function initialize(bytes calldata _encodedData) external initializer {
        address owner;
        address dao;
        address characterSheetsAddress;
        address hatsAddress;
        string memory baseUri;
        (dao, owner, characterSheetsAddress, hatsAddress, baseUri) =
            abi.decode(_encodedData, (address, address, address, address, string));

        hats = IHats(hatsAddress);
        _baseURI = baseUri;

        molochDao = IMolochDAO(dao);
        characterSheets = CharacterSheetsImplementation(characterSheetsAddress);

        _itemsCounter.increment();
        _classesCounter.increment();
        _tokenIdCounter.increment();

        // hats.mintTopHat(owner, "Default Admin hat", baseUri);
    }

    /**
     * Creates a new type of item
     * @param itemData the encoded data to create the item struct
     * @return tokenId this is the item id, used to find the item in items mapping
     * @return itemId this is the erc1155 token id
     */

    function createItemType(bytes calldata itemData)
        external
        virtual
        onlyDungeonMaster
        returns (uint256 tokenId, uint256 itemId)
    {
        Item memory newItem = _createItemStruct(itemData);
        //solhint-disable-next-line
        (bool success,) = address(this).call(abi.encodeWithSignature("findItemByName(string)", newItem.name));

        if(success){
            revert Errors.DuplicateError();
        }
        uint256 _tokenId = _tokenIdCounter.current();
        uint256 _itemId = _itemsCounter.current();

        _setURI(_tokenId, newItem.cid);
        _mint(address(this), _tokenId, newItem.supply, bytes(newItem.cid));

        newItem.tokenId = _tokenId;
        newItem.itemId = _itemId;
        items[_itemId] = newItem;

        emit NewItemTypeCreated(_itemId, _tokenId, newItem.name);

        _itemsCounter.increment();
        _tokenIdCounter.increment();

        totalItemTypes++;
        _tokenIdToItemId[_tokenId] = _itemId;
        return (_tokenId, _itemId);
    }

    /**
     *
     * @param classData encoded class data includes
     - string name
     - uint256 supply
     - string cid
     * @return tokenId the ERC1155 token id
     * @return classId the location of the class struct in the classes mapping
     */

    function createClassType(bytes calldata classData)
        external
        onlyDungeonMaster
        returns (uint256 tokenId, uint256 classId)
    {
        Class memory _newClass = _createClassStruct(classData);
        uint256 _classId = _classesCounter.current();
        uint256 _tokenId = _tokenIdCounter.current();

        _newClass.tokenId = _tokenId;
        _newClass.classId = _classId;
        classes[_classId] = _newClass;
        _tokenIdToClassId[_tokenId] = _classId;
        _setURI(_tokenId, _newClass.cid);
        emit NewClassCreated(_tokenId, _classId, _newClass.name);
        totalClasses++;
        _classesCounter.increment();
        _tokenIdCounter.increment();

        return (_tokenId, _classId);
    }


    function equipClass(uint256 characterId, uint256 classId) external onlyCharacter returns (bool) {
        CharacterSheet memory sheet = characterSheets.getCharacterSheetByCharacterId(characterId);
        Class memory class = classes[classId];
        if(balanceOf(sheet.ERC6551TokenAddress, class.tokenId) != 1){
            revert Errors.ClassError();
        }
        if(msg.sender != sheet.ERC6551TokenAddress){
            revert Errors.CharacterOnly();
        }
        characterSheets.equipClassToCharacter(characterId, classId);
        return true;
    }

    function equipItem(uint256 characterId, uint256 itemId) external onlyCharacter returns (bool) {
        CharacterSheet memory sheet = characterSheets.getCharacterSheetByCharacterId(characterId);
        Item memory item = items[itemId];
        if(balanceOf(sheet.ERC6551TokenAddress, item.tokenId) == 0){
            revert Errors.ItemError();
        }
        if(msg.sender != sheet.ERC6551TokenAddress){
            revert Errors.CharacterOnly();
        }
        characterSheets.equipItemToCharacter(characterId, itemId);
        return true;
    }

    function unequipItem(uint256 characterId, uint256 itemId) external onlyCharacter returns (bool) {
        CharacterSheet memory sheet = characterSheets.getCharacterSheetByCharacterId(characterId);
        Item memory item = items[itemId];
        if(balanceOf(sheet.ERC6551TokenAddress, item.tokenId) == 0){
            revert Errors.ItemError();
        }
        if(msg.sender != sheet.ERC6551TokenAddress){
            revert Errors.CharacterOnly();
        }
        characterSheets.unequipItemFromCharacter(characterId, itemId);
        return true;
    }

    function unequipClass(uint256 characterId, uint256 classId) external onlyCharacter returns (bool) {
        CharacterSheet memory sheet = characterSheets.getCharacterSheetByCharacterId(characterId);
        Class memory class = classes[classId];
        if(balanceOf(sheet.ERC6551TokenAddress, class.tokenId) != 1){
            revert Errors.ClassError();
        }
        if(msg.sender != sheet.ERC6551TokenAddress){
            revert Errors.CharacterOnly();
        }
        characterSheets.equipClassToCharacter(characterId, classId);
        return true;
    }

    function assignClasses(uint256 characterId, uint256[] calldata _classIds) external onlyDungeonMaster {
        for (uint256 i = 0; i < _classIds.length; i++) {
            assignClass(characterId, _classIds[i]);
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
                if (itemIds[i][j] == 0 && amounts[i][j] > 0) {
                    _giveExp(nftAddress[i], amounts[i][j]);
                } else {
                    Item memory newItem = items[itemIds[i][j]];

                    if (newItem.requirements.length > 0) {
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
        if(itemIds.length != amounts.length || itemIds.length != proofs.length){
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

                    if(!MerkleProof.verify(proofs[i], claimableItem.claimable, leaf)){
                        revert Errors.InvalidProof();
                    }
                    _transferItemWithReq(msg.sender, claimableItem.tokenId, amounts[i]);
                }
            }
        }
        success = true;
    }

    /**
     * gives an CHARACTER token a class.  can only assign one of each class type to each CHARACTER
     * @param characterId the tokenId of the player
     * @param classId the classId of the class to be assigned
     */

    function assignClass(uint256 characterId, uint256 classId) public onlyDungeonMaster {
        CharacterSheet memory player = characterSheets.getCharacterSheetByCharacterId(characterId);
        Class memory newClass = classes[classId];

        if(player.memberAddress == address(0x0)){
            revert Errors.PlayerError();
        }
        if(newClass.tokenId == 0){
            revert Errors.ClassError();
        }
        if(balanceOf(player.ERC6551TokenAddress, newClass.tokenId) != 0){
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
        if(tokenId == 0){
            revert Errors.ClassError();
        }
        if (characterSheets.hasRole(DUNGEON_MASTER, msg.sender)) {
            if (characterSheets.isClassEquipped(characterId, classId)) {
                if(
                    !characterSheets.unequipClassFromCharacter(characterId, classId)){
                        revert Errors.ClassError();
                    }
            }
            _burn(sheet.ERC6551TokenAddress, tokenId, 1);
        } else {
            if(sheet.memberAddress != msg.sender && sheet.ERC6551TokenAddress != msg.sender){
                revert Errors.OwnershipError();
            }
            if (characterSheets.isClassEquipped(characterId, classId)) {
                if(!characterSheets.unequipClassFromCharacter(characterId, classId)){
                    revert Errors.ClassError();
                }
            }
            _burn(sheet.ERC6551TokenAddress, tokenId, 1);
        }
        success = true;
    }

    /**
     * adds a new required item to the array of requirments in the item type
     * @param itemId the itemId of the item type to be modified
     * @param requiredTokenId the erc1155 token Id of the item to be added to the requirements array
     * @param amount the amount of the required item to be required
     */

    function addItemOrClassRequirement(uint256 itemId, uint256 requiredTokenId, uint256 amount)
        public
        onlyDungeonMaster
        returns (bool success)
    {
        (, bool isClass) = findItemOrClassIdFromTokenId(requiredTokenId);
        if (isClass) {
            if(amount != 1){
                revert Errors.ClassError();
            }
        }

        Item memory modifiedItem = items[itemId];
        bool duplicate;

        for (uint256 i = 0; i < modifiedItem.requirements.length; i++) {
            if (modifiedItem.requirements[i][0] == requiredTokenId) {
                duplicate = true;
            }
        }

        if(duplicate){
            revert Errors.DuplicateError();
        }
        uint256[] memory newRequirement = new uint256[](2);
        newRequirement[0] = requiredTokenId;
        newRequirement[1] = amount;

        items[itemId].requirements.push(newRequirement);
        success = true;

        return success;
    }

    /**
     *
     * @param itemId the itemId of the item type to be modified
     * @param removedItemId the itemId of the requirement that is to be removed.
     * so if the item requires 2 of itemId 1 to be burnt in order to claim the item then you put in 1
     *  and it will remove the requirment with itemId 1
     */
    function removeItemOrClassRequirement(uint256 itemId, uint256 removedItemId)
        public
        onlyDungeonMaster
        returns (bool)
    {
        uint256[][] memory arr = items[itemId].requirements;
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
            items[itemId].requirements = arr;
            items[itemId].requirements.pop();
        }

        return success;
    }

    /**
     *
     * @param itemId the item id of the item to be updated
     * @param merkleRoot the merkle root of the addresses and amounts that can be claimed of this item
     */

    function updateItemClaimable(uint256 itemId, bytes32 merkleRoot) public onlyDungeonMaster {
        if(items[itemId].tokenId == 0){
            revert Errors.ItemError();
        }
        items[itemId].claimable = merkleRoot;

        emit ItemUpdated(itemId);
    }

    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes calldata data)
        public
        override
    {
        if(!characterSheets.hasRole(CHARACTER, to)){
            revert Errors.CharacterOnly();
        }
        (uint256 itemId, bool isClass) = findItemOrClassIdFromTokenId(id);
        require(itemId > 0 && !isClass, "this item does not exist");
        Item memory item = items[itemId];
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
        if(ids.length != amounts.length){
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
     * @param _name a string with the name of the item.  is case sensetive so it is preffered that all names
     * are lowercase alphanumeric names enforced in the frontend.
     * @return tokenId the ERC1155 token id.
     * @return itemId the location of the item in the items mapping;
     */

    function findItemByName(string memory _name) public view returns (uint256 tokenId, uint256 itemId) {
        string memory temp = _name;
        for (uint256 i = 0; i <= totalItemTypes; i++) {
            if (keccak256(abi.encode(items[i].name)) == keccak256(abi.encode(temp))) {
                tokenId = items[i].tokenId;
                itemId = items[i].itemId;
                return (tokenId, itemId);
            }
        }
        revert Errors.ItemError();
    }

    /**
     *
     * @param _name the name of the class.  is case sensetive.
     * @return tokenId the ERC1155 token id.
     * @return classId storage location of the class in the classes mapping
     */

    function findClassByName(string calldata _name) public view returns (uint256 tokenId, uint256 classId) {
        string memory temp = _name;
        for (uint256 i = 0; i <= totalClasses; i++) {
            if (keccak256(abi.encode(classes[i].name)) == keccak256(abi.encode(temp))) {
                //classid, tokenId;
                tokenId = classes[i].tokenId;
                classId = classes[i].classId;
                return (tokenId, classId);
            }
        }
        revert Errors.ClassError();
    }

    /**
     *
     * @param tokenId the ERC1155 token id of the item  or class to be found
     * @return itemOrClassId the itemId or classId found
     * @return isClass true if the token is a class, false if It's an item
     */
    function findItemOrClassIdFromTokenId(uint256 tokenId) public view returns (uint256 itemOrClassId, bool isClass) {
        if (tokenId == 0) {
            itemOrClassId = 0;
            isClass = false;
            return (itemOrClassId, isClass);
        }
        if (_tokenIdToItemId[tokenId] > 0) {
            itemOrClassId = _tokenIdToItemId[tokenId];
            isClass = false;
            return (itemOrClassId, isClass);
        } else {
            itemOrClassId = _tokenIdToClassId[tokenId];
            if(itemOrClassId == 0){
                revert Errors.ItemError();
            }
            isClass = true;
            return (itemOrClassId, isClass);
        }
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

    function getClassById(uint256 classId) public view returns (Class memory) {
        return classes[classId];
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
        string memory tokenURI = _tokenURIs[tokenId];

        // If token URI is set, concatenate base URI and tokenURI (via abi.encodePacked).
        return bytes(tokenURI).length > 0 ? string(abi.encodePacked(_baseURI, tokenURI)) : _baseURI;
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
        _tokenURIs[tokenId] = tokenURI;
        emit URI(uri(tokenId), tokenId);
    }

    /**
     * @dev Sets `baseURI` as the `_baseURI` for all tokens
     */

    function _setBaseURI(string memory baseURI) internal {
        _baseURI = baseURI;
    }


    function _createClassStruct(bytes calldata classData)internal pure returns(Class memory){
        
        (string memory name, uint256 supply, string memory cid)= abi.decode(classData, (string, uint256, string));

        return Class(0,0, name, supply, cid);
    }

    function _createItemStruct(bytes memory data) internal pure returns (Item memory) {
        string memory name;
        uint256 supply;
        uint256[][] memory newRequirements;
        bool soulbound;
        bytes32 claimable;
        string memory cid;
        {
            (name, supply, newRequirements, soulbound, claimable, cid) =
                abi.decode(data, (string, uint256, uint256[][], bool, bytes32, string));
            return Item(0, 0, name, supply, 0, newRequirements, soulbound, claimable, cid);
        }
    }

    /**
     * private function for DM to give out experience.
     * @param _to player neft address
     * @param _amount the amount of exp to be issued
     */
    function _giveExp(address _to, uint256 _amount) private returns (uint256) {
        _mint(_to, EXPERIENCE, _amount, "");
        totalExperience += _amount;
        return totalExperience;
    }

    /**
     * internal function to transfer items.
     * @param _to the token bound account to receive the item;
     * @param tokenId the erc1155 id of the Item in the items mapping.
     * @param amount the amount of items to be sent to the player token
     */

    function _transferItem(address _to, uint256 tokenId, uint256 amount) private {
        (uint256 itemId, bool isClass) = findItemOrClassIdFromTokenId(tokenId);

        if(itemId == 0 || isClass == true){
            revert Errors.ItemError();
        }

        if(!characterSheets.hasRole(CHARACTER, _to)){
            revert Errors.CharacterOnly();
        }

        _balanceOf[address(this)][tokenId] -= amount;
        _balanceOf[_to][tokenId] += amount;

        items[itemId].supplied++;

        emit ItemTransfered(_to, tokenId, itemId);
    }

    /**
     * transfers an item that has requirements.
     * @param nftAddress the address of the token bound account of the player nft
     * @param tokenId the erc1155 Id of the item to be transfered
     * @param amount the number of items to be transfered
     */

    function _transferItemWithReq(address nftAddress, uint256 tokenId, uint256 amount) private returns (bool success) {
        
        if(!characterSheets.hasRole(CHARACTER, nftAddress)){
            revert Errors.CharacterOnly();
        }

        if (tokenId == 0 && amount > 0) {
            _giveExp(nftAddress, amount);
            success = true;
            return success;
        }

        (uint256 itemOrClassId, bool isClass) = findItemOrClassIdFromTokenId(tokenId);

        if(isClass){
            revert Errors.ClassError();
        }

        Item memory item = items[itemOrClassId];
        if(item.supply == 0){
            revert Errors.ItemError();
        }
        
        if(_checkRequirements(nftAddress, item.requirements, amount)){
        _balanceOf[address(this)][item.tokenId] -= amount;
        _balanceOf[nftAddress][item.tokenId] += amount;
        items[itemOrClassId].supplied += amount;

        emit ItemTransfered(nftAddress, item.tokenId, itemOrClassId);

        success = true;
        }
    }

    function _checkRequirements(address nftAddress, uint256[][] memory requirements, uint256 amount)
    private returns(bool){
      uint256[] memory newRequirement;
        
        for (uint256 i; i < requirements.length; i++) {
            newRequirement = requirements[i];

            (, bool requiredIsClass) = findItemOrClassIdFromTokenId(newRequirement[0]);
            if (!requiredIsClass) {
                if(
                    balanceOf(nftAddress, newRequirement[0]) < newRequirement[1] * amount){
                        revert Errors.RequirementError();
                    }

                _balanceOf[nftAddress][newRequirement[0]] -= newRequirement[1] * amount;
            } else if (requiredIsClass) {
                if(balanceOf(nftAddress, newRequirement[0]) != 1){
                    revert Errors.ClassError();
                }
            }
        }
        return true;
    }
}
