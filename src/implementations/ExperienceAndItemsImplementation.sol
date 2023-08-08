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

/**
 * @title Experience and Items
 * @author MrDeadCe11
 * @notice this is an ERC1155 that is designed to intereact with the characterSheets contract.
 * Each item and class is an 1155 token that can soulbound or not to the erc6551 wallet of each player nft
 * in the characterSHeets contract.
 */

struct Item {
    uint256 tokenId;
    string name;
    uint256 supply;
    uint256 supplied;
    uint256 experienceCost;
    uint256 hatId;
    bool soulbound;
    // if 0 then  items are claimable by anyone, otherwise upload a merkle root 
    //of all addresses allowed to claim.  if not claimable at all use any random bytes32 besides bytes32(0).
    bytes32 claimable;
    string cid;
}

struct Class {
    uint256 tokenId;
    string name;
    uint256 supply;
    string cid;
}


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

    // Optional base URI
    string private _baseURI = "";

    // Optional mapping for token URIs
    mapping(uint256 => string) private _tokenURIs;

    //mapping tokenId => item struct for gear and classes;
    mapping(uint256 => Item) public items;
    mapping(uint256 => Class) public classes;
    mapping(address => uint256[]) public ownedItems;
    mapping(address => uint256[]) public assignedClasses;

    uint256 public constant EXPERIENCE = 0;

    uint256 public totalClasses;
    uint256 public totalItemTypes;
    uint256 public totalExperience;

    address private _dao;

    IMolochDAO molochDao;
    CharacterSheetsImplementation characterSheets;
    IHats hats;

    event NewItemTypeCreated(uint256, uint256, string);
    event NewClassCreated(uint256, uint256, string, string);
    event ClassAssigned(address, uint256, address);
    event ItemTransfered(address, uint256, uint256);
    event ItemUpdated(Item);

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

        _dao = dao;
        molochDao = IMolochDAO(dao);
        characterSheets = CharacterSheetsImplementation(characterSheetsAddress);

        _itemsCounter.increment();
        _classesCounter.increment();
        _tokenIdCounter.increment();

        hats.mintTopHat(owner, "Dungeon Master hat", baseUri);
    }

    /**
     * Creates a new item
     * @param _newItem takes an Item struct
     * @return tokenId this is the item id, used to find the item in items mapping
     * @return itemId this is the erc1155 token id
     */

    function createItemType(Item memory _newItem)
        public
        virtual
        onlyDungeonMaster
        returns (uint256 tokenId, uint256 itemId)
    {
        (bool success, bytes memory __) =
            address(this).call(abi.encodeWithSignature("findItemByName(string)", _newItem.name));

        require(!success, "Item already exists.");
        uint256 _tokenId = _tokenIdCounter.current();
        uint256 _itemId = _itemsCounter.current();

        _setURI(_tokenId, _newItem.cid);
        _mint(address(this), _tokenId, _newItem.supply, bytes(_newItem.cid));

        _newItem.tokenId = _tokenId;
        items[_itemId] = _newItem;

        emit NewItemTypeCreated(_itemId, _tokenId, _newItem.name);

        _itemsCounter.increment();
        _tokenIdCounter.increment();

        totalItemTypes++;

        return (_tokenId, _itemId);
    }

    /**
     *
     * @param _newClass A class struct with all the class details filled out
     * @return tokenId the ERC1155 token id
     * @return classId the location of the class in the classes mapping
     */

    function createClassType(Class memory _newClass)
        public
        onlyDungeonMaster
        returns (uint256 tokenId, uint256 classId)
    {
        uint256 _classId = _classesCounter.current();
        uint256 _tokenId = _tokenIdCounter.current();

        _newClass.tokenId = _tokenId;
        classes[_classId] = _newClass;
        _setURI(_tokenId, _newClass.cid);
        emit NewClassCreated(_tokenId, _classId, _newClass.name, _newClass.cid);
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
                itemId = i;
                tokenId = items[i].tokenId;
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
                classId = i;
                return (tokenId, classId);
            }
        }
        revert("No class found.");
    }

    /**
     * returns an array of all Class structs stored in the classes mapping
     */

    function getAllClasses() public view returns (Class[] memory) {
        Class[] memory allClasses = new Class[](totalClasses);
        for (uint256 i = 1; i <= totalClasses; i++) {
            allClasses[i] = classes[i];
        }
        return allClasses;
    }

    /**
     * returns an array of all Item structs in the Item's mapping
     */
    function getAllItems() public view returns (Item[] memory) {
        Item[] memory allItems = new Item[](totalItemTypes);
        for (uint256 i = 1; i <= totalItemTypes; i++) {
            allItems[i] = items[i];
        }
        return allItems;
    }

    function assignClass(uint256 _playerId, uint256 _classId) public onlyDungeonMaster {
        CharacterSheet memory player = characterSheets.getCharacterSheetByPlayerId(_playerId);
        Class memory newClass = classes[_classId];
        require(molochDao.members(player.memberAddress).shares > 0, "This person is not a member");
        require(player.memberAddress != address(0x0), "This member is not a player character");
        require(newClass.tokenId > 0, "This class does not exist.");

        address playerNFT = player.ERC6551TokenAddress;
        _mint(playerNFT, newClass.tokenId, 1, bytes(newClass.cid));

        classes[_classId].supply++;

        emit ClassAssigned(player.memberAddress, _classId, playerNFT);
    }

    function assignClasses(uint256 _playerId, uint256[] calldata _classIds) external onlyDungeonMaster {
        for (uint256 i = 0; i < _classIds.length; i++) {
            assignClass(_playerId, _classIds[i]);
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
     * drops loot and/or exp after a completed quest items dropped through dropLoot do cost exp.
     * @param nftAddress the tokenbound account of the character npc to receive the item
     * @param itemIds the item Id's of the loot to be dropped  exp is allways Item Id 0;
     * @param amounts the amounts of each item to be dropped this must be in sync with the item ids
     */

    function dropLoot(address[] calldata nftAddress, uint256[] calldata itemIds, uint256[] calldata amounts)
        public
        onlyDungeonMaster
    {
        for (uint256 i; i < nftAddress.length; i++) {
            uint256 playerId = characterSheets.getPlayerIdByNftAddress(nftAddress[i]);
            for (uint256 j; j < itemIds.length; j++) {
                if (items[itemIds[j]].experienceCost > 0) {
                    _transferItem(nftAddress[i], itemIds[j], amounts[j]);
                } else {
                    _transferItemWithExp(playerId, itemIds[j], amounts[j]);
                }
            }
        }
    }
    /**
     * internal function to transfer items.
     * @param _to the tokenId of the player Token on the characterSheets
     * @param itemId the id of the Item in the items mapping.
     * @param amount the amount of items to be sent to the player token
     */

    function _transferItem(address _to, uint256 itemId, uint256 amount) private {
        Item memory item = items[itemId];

        require(characterSheets.hasRole(NPC, _to), "Can Only transfer Items to an NPC");
        require(itemId != 0, "cannot give exp");
        require(item.supply > 0, "Item does not exist");

        _balanceOf[address(this)][item.tokenId] -= amount;
        _balanceOf[_to][item.tokenId] += amount;

        emit ItemTransfered(_to, itemId, item.tokenId);
    }

    function _transferItemWithExp(uint256 playerId, uint256 itemId, uint256 amount) private {
        Item memory item = items[itemId];
        CharacterSheet memory player = characterSheets.getCharacterSheetByPlayerId(playerId);

        require(player.ERC6551TokenAddress > address(0), "Player does not exist");
        if (itemId == 0) {
            _giveExp(player.ERC6551TokenAddress, amount);
        } else {
            require(item.supply > 0, "Item does not exist");
            require(
                balanceOf(player.ERC6551TokenAddress, EXPERIENCE) >= item.experienceCost * amount,
                "You do not have enough experience to claim this item."
            );

            _balanceOf[player.ERC6551TokenAddress][EXPERIENCE] -= item.experienceCost * amount;
            _balanceOf[address(this)][item.tokenId] -= amount;
            _balanceOf[player.ERC6551TokenAddress][item.tokenId] += amount;

            emit ItemTransfered(player.ERC6551TokenAddress, itemId, item.tokenId);
        }
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

        uint256 playerId = characterSheets.getPlayerIdByNftAddress(msg.sender);
        for (uint256 i = 0; i < itemIds.length; i++) {
            Item memory claimableItem = items[itemIds[i]];
            if(claimableItem.claimable == bytes32(0)){
            require(characterSheets.hasRole(NPC, msg.sender), "Only an NPC can claim items");
            _transferItemWithExp(playerId, itemIds[i], amounts[i]);
            } else {
            bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encodePacked(itemIds[i], msg.sender, amounts[i]))));

            require(MerkleProof.verify(proofs[i], claimableItem.claimable, leaf), "Merkle Proof Failed");
            _transferItemWithExp(playerId, itemIds[i], amounts[i]);
            }
        }
        success = true;
    }

    function updateItemClaimable(uint256 itemId, bytes32 merkleRoot) public onlyDungeonMaster {
        items[itemId].claimable = merkleRoot;

        emit ItemUpdated(items[itemId]);
    }
    // The following functions are overrides required by Solidity.

    function setApprovalForAll(address operator, bool approved) public override(ERC1155) onlyDungeonMaster {
        super.setApprovalForAll(operator, approved);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC1155Receiver, ERC1155) returns (bool) {
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

    //#TODO OVER RIDE TRANSFER FUNCTIONS etc for correct soulbinding of tokens.
}
