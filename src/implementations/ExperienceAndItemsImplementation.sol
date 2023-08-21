// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "openzeppelin/utils/cryptography/MerkleProof.sol";
import "openzeppelin/utils/Strings.sol";
import "hats-protocol/lib/ERC1155/ERC1155.sol";
import "hats-protocol/src/Interfaces/IHats.sol";
import "openzeppelin/token/ERC721/IERC721.sol";
import "openzeppelin/token/ERC1155/utils/ERC1155Holder.sol";
import "openzeppelin/utils/Counters.sol";

import "../implementations/CharacterSheetsImplementation.sol";
import "../interfaces/IMolochDAO.sol";
import "forge-std/console2.sol";
import "../lib/Structs.sol";

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
    bytes32 public constant NPC = keccak256("NPC");

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
    mapping(uint256 => uint256) internal tokenIdToItemId;
    /// @dev mapping of erc1155 tokenID of a class to the class Id;
    mapping(uint256 => uint256) internal tokenIdToClassId;
    /// @dev tokenId 0 is experience which is infinite supply and can be minted by any dungeon master or claimed by a player.
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
    event ItemTransfered(address itemTransferedTo, uint256 erc1155TokenId, uint256 ItemId);
    event ItemUpdated(uint256 itemId);

    modifier onlyDungeonMaster() {
        require(characterSheets.hasRole(DUNGEON_MASTER, msg.sender), "You must be the Dungeon Master");
        _;
    }

    modifier onlyPlayer() {
        require(characterSheets.hasRole(PLAYER, msg.sender), "You must be a Player");
        _;
    }

    modifier onlyNPC() {
        require(characterSheets.hasRole(NPC, msg.sender), "Must be an npc");
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

        hats.mintTopHat(owner, "Default Admin hat", baseUri);
    }

    /**
     * Creates a new type of item
     * @param itemData the encoded data to create the item struct
     * @return tokenId this is the item id, used to find the item in items mapping
     * @return itemId this is the erc1155 token id
     */

    function createItemType(bytes calldata itemData)
        public
        virtual
        onlyDungeonMaster
        returns (uint256 tokenId, uint256 itemId)
    {
        Item memory newItem = createItemStruct(itemData);
        (bool success,) = address(this).call(abi.encodeWithSignature("findItemByName(string)", newItem.name));

        require(!success, "Item already exists.");
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
        tokenIdToItemId[_tokenId] = _itemId;
        return (_tokenId, _itemId);
    }

    function createItemStruct(bytes memory data) internal pure returns (Item memory) {
        string memory name;
        uint256 supply;
        uint256[][] memory newRequirements;
        bool soulbound;
        bytes32 claimable;
        string memory cid;
        {
            // (_name, _soulbound, 10**18, newRequirements,0, false, _claimable,  'test_item_cid/');
            (name, supply, newRequirements, soulbound, claimable, cid) =
                abi.decode(data, (string, uint256, uint256[][], bool, bytes32, string));
            return Item(0, 0, name, supply, 0, newRequirements, soulbound, claimable, cid);
        }
    }

    /**
     *
     * @param _newClass A class struct with all the class details filled out
     * @return tokenId the ERC1155 token id
     * @return classId the location of the class struct in the classes mapping
     */

    function createClassType(Class memory _newClass)
        public
        onlyDungeonMaster
        returns (uint256 tokenId, uint256 classId)
    {
        uint256 _classId = _classesCounter.current();
        uint256 _tokenId = _tokenIdCounter.current();

        _newClass.tokenId = _tokenId;
        _newClass.classId = _classId;
        classes[_classId] = _newClass;
        tokenIdToClassId[_tokenId] = _classId;
        _setURI(_tokenId, _newClass.cid);
        emit NewClassCreated(_tokenId, _classId, _newClass.name);
        totalClasses++;
        _classesCounter.increment();
        _tokenIdCounter.increment();

        return (_tokenId, _classId);
    }

    /**
     *
     * @param _name a string with the name of the item.  is case sensetive so it is preffered that all names are lowercase alphanumeric names enforced in the frontend.
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
        revert("No item found.");
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
        revert("No class found.");
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
        if (tokenIdToItemId[tokenId] > 0) {
            itemOrClassId = tokenIdToItemId[tokenId];
            isClass = false;
            return (itemOrClassId, isClass);
        } else {
            itemOrClassId = tokenIdToClassId[tokenId];
            require(itemOrClassId > 0, "this tokenId is not an item or a class");
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

    /**
     * gives an npc token a class.  can only assign one of each class type to each NPC
     * @param playerId the tokenId of the player
     * @param classId the classId of the class to be assigned
     */

    function assignClass(uint256 playerId, uint256 classId) public onlyDungeonMaster {
        CharacterSheet memory player = characterSheets.getCharacterSheetByPlayerId(playerId);
        Class memory newClass = classes[classId];

        require(player.memberAddress != address(0x0), "This member is not a player");
        require(newClass.tokenId > 0, "This class does not exist.");
        require(balanceOf(player.ERC6551TokenAddress, newClass.tokenId) == 0, "Can only assign a class once.");

        _mint(player.ERC6551TokenAddress, newClass.tokenId, 1, bytes(newClass.cid));

        classes[classId].supply++;

        emit ClassAssigned(player.ERC6551TokenAddress, newClass.tokenId, classId);
    }

    function equipClass(uint256 playerId, uint256 classId) external onlyNPC returns (bool) {
        CharacterSheet memory sheet = characterSheets.getCharacterSheetByPlayerId(playerId);
        Class memory class = classes[classId];
        require(balanceOf(sheet.ERC6551TokenAddress, class.tokenId) == 1, "NPC has not been assigned this class.");
        require(msg.sender == sheet.ERC6551TokenAddress, "Incorrect NPC");
        characterSheets.equipClassToNPC(playerId, classId);
        return true;
    }

    function equipItem(uint256 playerId, uint256 itemId) external onlyNPC returns (bool) {
        CharacterSheet memory sheet = characterSheets.getCharacterSheetByPlayerId(playerId);
        Item memory item = items[itemId];
        require(balanceOf(sheet.ERC6551TokenAddress, item.tokenId) >= 1, "NPC has not been assigned this class.");
        require(msg.sender == sheet.ERC6551TokenAddress, "Incorrect NPC");
        characterSheets.equipItemToNPC(playerId, itemId);
        return true;
    }

    function unequipItem(uint256 playerId, uint256 itemId) external onlyNPC returns (bool) {
        CharacterSheet memory sheet = characterSheets.getCharacterSheetByPlayerId(playerId);
        Item memory item = items[itemId];
        require(balanceOf(sheet.ERC6551TokenAddress, item.tokenId) >= 1, "NPC has not been assigned this class.");
        require(msg.sender == sheet.ERC6551TokenAddress, "Incorrect NPC");
        characterSheets.unequipItemFromNPC(playerId, itemId);
        return true;
    }

    function unequipClass(uint256 playerId, uint256 classId) external onlyNPC returns (bool) {
        CharacterSheet memory sheet = characterSheets.getCharacterSheetByPlayerId(playerId);
        Class memory class = classes[classId];
        require(balanceOf(sheet.ERC6551TokenAddress, class.tokenId) == 1, "NPC has not been assigned this class.");
        require(msg.sender == sheet.ERC6551TokenAddress, "Incorrect NPC");
        characterSheets.equipClassToNPC(playerId, classId);
        return true;
    }

    function assignClasses(uint256 playerId, uint256[] calldata _classIds) external onlyDungeonMaster {
        for (uint256 i = 0; i < _classIds.length; i++) {
            assignClass(playerId, _classIds[i]);
        }
    }

    /**
     * removes a class from a player token
     * @param playerId the token Id of the player who needs a class removed
     * @param classId the class to be removed
     */

    function revokeClass(uint256 playerId, uint256 classId) public returns (bool success) {
        CharacterSheet memory sheet = characterSheets.getCharacterSheetByPlayerId(playerId);
        uint256 tokenId = classes[classId].tokenId;
        require(tokenId > 0, "this is not a class");
        if (characterSheets.hasRole(DUNGEON_MASTER, msg.sender)) {
            if(characterSheets.isClassEquipped(playerId, classId)){
            require(characterSheets.unequipClassFromNPC(playerId, classId), "Player does not have that class");
            }
            _burn(sheet.ERC6551TokenAddress, tokenId, 1);
        } else {
            require(sheet.memberAddress == msg.sender || sheet.ERC6551TokenAddress == msg.sender, "Must be the player or NPC to remove a class");
            if(characterSheets.isClassEquipped(playerId, classId)){
            require(characterSheets.unequipClassFromNPC(playerId, classId), "You do not have that class");
            }
            _burn(sheet.ERC6551TokenAddress, tokenId, 1);
        }
        success = true;
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
            require(amount == 1, "NPC can only have one class token");
        }

        Item memory modifiedItem = items[itemId];
        bool duplicate;

        for (uint256 i = 0; i < modifiedItem.requirements.length; i++) {
            if (modifiedItem.requirements[i][0] == requiredTokenId) {
                duplicate = true;
            }
        }

        require(!duplicate, "Cannot add a requirement that has already been added");
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
     * drops loot and/or exp after a completed quest items dropped through dropLoot do cost exp.
     * @param nftAddress the tokenbound account of the character npc to receive the item
     * @param itemIds the item Id's of the loot to be dropped  exp is allways Item Id 0;
     * @param amounts the amounts of each item to be dropped this must be in sync with the item ids
     */

    function dropLoot(address[] calldata nftAddress, uint256[][] calldata itemIds, uint256[][] calldata amounts)
        external
        onlyDungeonMaster
        returns (bool success)
    {
        require( nftAddress.length == itemIds.length && itemIds.length == amounts.length, "LENGTH MISMATCH");
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
     * internal function to transfer items.
     * @param _to the token bound account to receive the item;
     * @param tokenId the erc1155 id of the Item in the items mapping.
     * @param amount the amount of items to be sent to the player token
     */

    function _transferItem(address _to, uint256 tokenId, uint256 amount) private {
        (uint256 itemId, bool isClass) = findItemOrClassIdFromTokenId(tokenId);

        require(itemId != 0 || isClass == false, "cannot transfer exp or classes");

        Item memory item = items[itemId];

        require(characterSheets.hasRole(NPC, _to), "Can Only transfer Items to an NPC");

        require(item.supply > 0, "Item does not exist");

        _balanceOf[address(this)][item.tokenId] -= amount;
        _balanceOf[_to][item.tokenId] += amount;

        items[itemId].supplied++;

        emit ItemTransfered(_to, item.tokenId, itemId);
    }

    /**
     * transfers an item that costs exp.  takes the exp from the npc nft and transfers the item
     * @param NFTAddress the address of the token bound account of the player nft
     * @param tokenId the erc1155 Id of the item to be transfered
     * @param amount the number of items to be transfered
     */

    function _transferItemWithReq(address NFTAddress, uint256 tokenId, uint256 amount) private returns (bool success) {
        require(characterSheets.hasRole(NPC, NFTAddress), "Can only transfer Items to an NPC");

        require(amount > 0, "Cannot transfer 0 of anything");

        if (tokenId == 0 && amount > 0) {
            _giveExp(NFTAddress, amount);
            success = true;
            return success;
        }

        (uint256 itemOrClassId, bool isClass) = findItemOrClassIdFromTokenId(tokenId);

        require(!isClass, "Cannot transfer classes");

        Item memory item = items[itemOrClassId];
        require(item.supply > 0, "Item does not exist");
        uint256[] memory newRequirement;

        for (uint256 i; i < item.requirements.length; i++) {
            newRequirement = item.requirements[i];

            (, bool requiredIsClass) = findItemOrClassIdFromTokenId(newRequirement[0]);
            if (!requiredIsClass) {
                require(
                    balanceOf(NFTAddress, newRequirement[0]) >= newRequirement[1] * amount, "Not enough required item."
                );

                _balanceOf[NFTAddress][newRequirement[0]] -= newRequirement[1] * amount;
            } else if (requiredIsClass) {
                require(balanceOf(NFTAddress, newRequirement[0]) == 1, "Character does not have this class");
            }
        }

        _balanceOf[address(this)][item.tokenId] -= amount;
        _balanceOf[NFTAddress][item.tokenId] += amount;
        items[itemOrClassId].supplied += amount;

        emit ItemTransfered(NFTAddress, item.tokenId, itemOrClassId);

        success = true;
    }

    /**
     * this is to be claimed from the ERC6551 wallet of the player sheet.
     * @param itemIds an array of item ids
     * @param amounts an array of amounts to claim, must match the order of item ids
     * @param proofs an array of proofs allowing this address to claim the item,  must be in same order as item ids and amounts
     */

    function claimItems(uint256[] calldata itemIds, uint256[] calldata amounts, bytes32[][] calldata proofs)
        public
        onlyNPC
        returns (bool success)
    {
        require(itemIds.length == amounts.length && itemIds.length == proofs.length, "mismatch in array lengths");

        for (uint256 i = 0; i < itemIds.length; i++) {
            if (itemIds[i] == 0) {
                _giveExp(msg.sender, amounts[i]);
            } else if (items[itemIds[i]].tokenId == 0) {
                revert("can only claim Items");
            } else {
                Item memory claimableItem = items[itemIds[i]];
                if (claimableItem.claimable == bytes32(0)) {
                    require(characterSheets.hasRole(NPC, msg.sender), "Only an NPC can claim items");
                    _transferItemWithReq(msg.sender, claimableItem.tokenId, amounts[i]);
                } else {
                    bytes32 leaf =
                        keccak256(bytes.concat(keccak256(abi.encodePacked(itemIds[i], msg.sender, amounts[i]))));

                    require(MerkleProof.verify(proofs[i], claimableItem.claimable, leaf), "Merkle Proof Failed");
                    _transferItemWithReq(msg.sender, claimableItem.tokenId, amounts[i]);
                }
            }
        }
        success = true;
    }

    function getItemById(uint256 itemId) public view returns (Item memory) {
        return items[itemId];
    }

    function getClassById(uint256 classId) public view returns (Class memory) {
        return classes[classId];
    }

    /**
     *
     * @param itemId the item id of the item to be updated
     * @param merkleRoot the merkle root of the addresses and amounts that can be claimed of this item
     */

    function updateItemClaimable(uint256 itemId, bytes32 merkleRoot) public onlyDungeonMaster {
        require(items[itemId].tokenId != 0, "this is not a registered item");
        items[itemId].claimable = merkleRoot;

        emit ItemUpdated(itemId);
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

    // The following functions are overrides required by Solidity.

    function setApprovalForAll(address operator, bool approved) public override {
        super.setApprovalForAll(operator, approved);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC1155Receiver, ERC1155) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes calldata data)
        public
        override
    {
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
        require(ids.length == amounts.length, "LENGTH_MISMATCH");

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
}
