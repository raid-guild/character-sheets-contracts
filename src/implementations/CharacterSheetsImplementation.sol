// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
pragma abicoder v2;

import "openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import "openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "openzeppelin-contracts/contracts/access/AccessControl.sol";
import "openzeppelin-contracts/contracts/utils/Counters.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "../interfaces/IERC6551Registry.sol";
import "../interfaces/IMolochDAO.sol";
import "./ExperienceAndItemsImplementation.sol";
import "forge-std/console2.sol";
import "../lib/Structs.sol";

contract CharacterSheetsImplementation is Initializable, ERC721, ERC721URIStorage, AccessControl {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;

    bytes32 public constant DUNGEON_MASTER = keccak256("DUNGEON_MASTER");
    bytes32 public constant PLAYER = keccak256("PLAYER");
    bytes32 public constant NPC = keccak256("NPC");

    ExperienceAndItemsImplementation public experience;

    IMolochDAO public dao;

    string public baseTokenURI;

    IERC6551Registry _erc6551Registry;
    address erc6551AccountImplementation;

    event NewPlayer(uint256 tokenId, address memberAddress);
    event PlayerRemoved(uint256 tokenId);
    event ExperienceUpdated(address exp);
    event ClassAdded(uint256 playerid, uint256 classId);
    event ItemAdded(uint256 playerId, uint256 itemTokenId);
    event PlayerNameUpdated(string oldName, string newName);

    // tokenId => characterSheet
    mapping(uint256 => CharacterSheet) public players;
    // member address => characterSheet token Id.
    mapping(address => uint256) public memberAddressToTokenId;

    uint256 totalSheets;

    constructor() ERC721("CharacterSheet", "CHAS") {
        _disableInitializers();
    }

    modifier onlyExpContract() {
        require(msg.sender == address(experience), "not the experience contract");
        _;
    }
    /**
     *
     * @param _encodedParameters encoded parameters must include:
     * - address daoAddress the address of the dao who's member list will be allowed to become players and who will be able to interact with this contract
     * - address[] dungeonMasters an array addresses of the person/persons who are authorized to issue player cards, classes, and items.
     * - string baseURI the default uri of the player card images, arbitrary a different uri can be set when the character sheet is minted.
     * - address experienceImplementation this is the address of the ERC1155 experience contract associated with this contract.  this is assigned at contract creation.
     */

    function initialize(bytes calldata _encodedParameters) public initializer {
        _grantRole(DUNGEON_MASTER, msg.sender);

        address daoAddress;
        address[] memory dungeonMasters;
        address owner;
        address NPCAccountImplementation;
        address erc6551Registry;
        string memory baseUri;
        address experienceImplementation;

        (
            daoAddress,
            dungeonMasters,
            owner,
            experienceImplementation,
            erc6551Registry,
            NPCAccountImplementation,
            baseUri
        ) = abi.decode(_encodedParameters, (address, address[], address, address, address, address, string));

        _grantRole(DEFAULT_ADMIN_ROLE, owner);

        for (uint256 i = 0; i < dungeonMasters.length; i++) {
            _grantRole(DUNGEON_MASTER, dungeonMasters[i]);
        }

        setBaseUri(baseUri);
        experience = ExperienceAndItemsImplementation(experienceImplementation);
        dao = IMolochDAO(daoAddress);
        erc6551AccountImplementation = NPCAccountImplementation;
        _erc6551Registry = IERC6551Registry(erc6551Registry);
        _tokenIdCounter.increment();

        _revokeRole(DUNGEON_MASTER, msg.sender);
    }

    /**
     *
     * @param _to the address of the dao member wallet that will hold the character sheet nft
     * @param _data encoded data that contains the name of the member and the uri of the base image for the nft.
     * if no uri is stored then it will revert to the base uri of the contract
     */

    function rollCharacterSheet(address _to, bytes calldata _data) public onlyRole(DUNGEON_MASTER) {
        require(
            erc6551AccountImplementation != address(0) && address(_erc6551Registry) != address(0),
            "ERC6551 acount implementation and registry not set"
        );

        require(dao.members(_to).shares > 0, "Player is not a member of the dao");

        string memory _newName;
        string memory _tokenURI;
        (_newName, _tokenURI) = abi.decode(_data, (string, string));

        uint256 tokenId = _tokenIdCounter.current();

        require(memberAddressToTokenId[_to] == 0, "this player is already in the game");

        _tokenIdCounter.increment();
        _safeMint(_to, tokenId);

        if (bytes(_tokenURI).length > 0) {
            _setTokenURI(tokenId, _tokenURI);
        } else {
            _setTokenURI(tokenId, baseTokenURI);
        }

        //calculate ERC6551 account address
        address tba =
            _erc6551Registry.createAccount(erc6551AccountImplementation, block.chainid, address(this), tokenId, 0, "");

        CharacterSheet memory newCharacterSheet;
        newCharacterSheet.name = _newName;
        newCharacterSheet.ERC6551TokenAddress = tba;
        newCharacterSheet.memberAddress = _to;
        newCharacterSheet.tokenId = tokenId;
        //store info in mappings
        players[tokenId] = newCharacterSheet;
        memberAddressToTokenId[_to] = tokenId;

        totalSheets++;
        _grantRole(PLAYER, _to);
        _grantRole(NPC, tba);
        emit NewPlayer(tokenId, _to);
    }

    /**
     * this adds a class to the classes array of the characterSheet struct in storage
     * @param playerId the token id of the player to receive a class
     * @param classId the class ID of the class to be added
     */

    function addClassToPlayer(uint256 playerId, uint256 classId) external onlyExpContract {
        players[playerId].classes.push(classId);
        emit ClassAdded(playerId, classId);
    }
    
    /**
     * removes a class from a character Sheet
     * @param playerId the id of the character sheet to be modified
     * @param classId the class Id to be removed
     */

    function removeClassFromPlayer(uint256 playerId, uint256 classId) external onlyExpContract returns (bool success) {
        uint256[] memory arr = players[playerId].classes;
        for (uint256 i = 0; i < arr.length; i++) {
            if (arr[i] == classId) {
                for (uint256 j = i; j < arr.length; j++) {
                    if (j + 1 < arr.length) {
                        arr[j] = arr[j + 1];
                    } else if (j + 1 >= arr.length) {
                        arr[j] = 0;
                    }
                }
                players[playerId].classes = arr;
                players[playerId].classes.pop();

                return success = true;
            }
        }
        return success = false;
    }

    /**
     * removes an itemtype from a character sheet inventory
     * @param playerId the player to have the item type from their inventory
     * @param tokenId the erc1155 token id of the item to be removed
     */

    function removeItemFromPlayer(uint256 playerId, uint256 tokenId) external onlyExpContract returns (bool success) {
        uint256[] memory arr = players[playerId].items;
        require(experience.balanceOf(players[playerId].ERC6551TokenAddress, tokenId) == 0, "empty your inventory first");
        for (uint256 i = 0; i < arr.length; i++) {
            if (arr[i] == tokenId) {
                for (uint256 j = i; j < arr.length; j++) {
                    if (j + 1 < arr.length) {
                        arr[j] = arr[j + 1];
                    } else if (j + 1 >= arr.length) {
                        arr[j] = 0;
                    }
                }
                players[playerId].items = arr;
                players[playerId].items.pop();

                return success = true;
            }
        }
        return success = false;
    }

    /**
     * adds an item to the items array in the player struct
     * @param playerId the id of the player receiving the item
     * @param itemTokenId the itemId of the item
     */

    function addItemToPlayer(uint256 playerId, uint256 itemTokenId) external onlyExpContract {
        players[playerId].items.push(itemTokenId);
        emit ItemAdded(playerId, itemTokenId);
    }

    function getCharacterSheetByPlayerId(uint256 tokenId) public view returns (CharacterSheet memory) {
        require(players[tokenId].memberAddress > address(0), "This is not a character.");
        return players[tokenId];
    }

    function getPlayerIdByNftAddress(address _nftAddress) public view returns (uint256) {
        for (uint256 i = 1; i <= totalSheets; i++) {
            if (players[i].ERC6551TokenAddress == _nftAddress) {
                return i;
            }
        }
        revert("This is not the address of an npc");
    }

    /**
     * returns the index of the class in the character sheet classes array
     * @param playerId token id of the character sheet to be modified
     * @param classId the classId to be indexed
     * returns the index of the class in the classes
     */
    function getClassIndex(uint256 playerId, uint256 classId) public view returns (uint256 indexOfClass) {
        CharacterSheet memory sheet = players[playerId];
        uint256 length = sheet.classes.length;
        for (uint256 i = 0; i < length; i++) {
            if (sheet.classes[i] == classId) {
                indexOfClass = i;
            }
        }
        revert("this player does not have this class");
    }

    function updateExpContract(address expContract) external onlyRole(DUNGEON_MASTER) {
        experience = ExperienceAndItemsImplementation(expContract);
        emit ExperienceUpdated(expContract);
    }

    /**
     * Burns a players characterSheet.  can only be done if there is a passing guild kick proposal
     * @param _tokenId the playerId of the player to be removed.
     */

    function removeSheet(uint256 _tokenId) public onlyRole(DUNGEON_MASTER) {
        require(
            dao.members(getCharacterSheetByPlayerId(_tokenId).memberAddress).jailed > 0,
            "There has been no passing guild kick proposal on this player."
        );
        delete players[_tokenId];
        _burn(_tokenId);

        emit PlayerRemoved(_tokenId);
    }

    /**
     * this will burn the nft of the player.  only a player can burn their own token.
     * @param _playerId the token id to be burned
     */

    function renounceSheet(uint256 _playerId) public returns (bool success) {
        require(balanceOf(msg.sender) > 0, "you do not have a characterSheet");
        address tokenOwner = ownerOf(_playerId);
        require(msg.sender == tokenOwner, "You cannot renounce a token you don't own");
        _burn(_playerId);
        emit PlayerRemoved(_playerId);
        success = true;
    }

    /**
     * allows a player to update their name in the contract
     * @param newName the new player name
     */
    function updatePlayerName(string calldata newName) public onlyRole(PLAYER) {
        string memory oldName = players[memberAddressToTokenId[msg.sender]].name;
        players[memberAddressToTokenId[msg.sender]].name = newName;

        emit PlayerNameUpdated(oldName, newName);
    }

    function setExperienceAndGearContract(address _experience) public onlyRole(DUNGEON_MASTER) {
        experience = ExperienceAndItemsImplementation(_experience);
    }

    function setBaseUri(string memory _uri) public onlyRole(DUNGEON_MASTER) {
        baseTokenURI = _uri;
    }

    // The following functions are overrides required by Solidity.

    function _baseURI() internal view virtual override returns (string memory) {
        return baseTokenURI;
    }

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    /// @dev Sets the address of the ERC6551 registry
    function setERC6551Registry(address registry) public onlyRole(DUNGEON_MASTER) {
        _erc6551Registry = IERC6551Registry(registry);
    }

    /// @dev Sets the address of the ERC6551 account implementation
    function setERC6551Implementation(address implementation) public onlyRole(DUNGEON_MASTER) {
        erc6551AccountImplementation = implementation;
    }

    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721URIStorage, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    // transfer overrides since these tokens should be soulbound or only transferable by the dungeonMaster

    /**
     * @dev See {IERC721-approve}.
     */
    // solhint-disable-next-line unused-var
    function approve(address to, uint256 tokenId) public virtual override(ERC721, IERC721) {
        revert("This token cannot be transfered");
    }

    /**
     * @dev See {IERC721-setApprovalForAll}.
     */
    function setApprovalForAll(address operator, bool approved) public virtual override(ERC721, IERC721) {
        revert("This token cannot be transfered");
    }

    /**
     * @dev See {IERC721-transferFrom}.
     */
    function transferFrom(address from, address to, uint256 tokenId) public virtual override(ERC721, IERC721) {
        revert("Cannot transfer characterSheets");
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(address from, address to, uint256 tokenId) public virtual override(ERC721, IERC721) {
        revert("Cannot transfer characterSheets");
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data)
        public
        virtual
        override(ERC721, IERC721)
    {
        revert("Cannot transfer characterSheets");
    }
}
