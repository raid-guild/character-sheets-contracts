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

contract CharacterSheetsImplementation is Initializable, IMolochDAO, ERC721, ERC721URIStorage, AccessControl {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;

    bytes32 public constant DUNGEON_MASTER = keccak256("DUNGEON_MASTER");
    bytes32 public constant PLAYER = keccak256("PLAYER");
    bytes32 public constant NPC = keccak256("NPC");

    ExperienceAndItemsImplementation _experience;

    IMolochDAO internal _dao;

    string private _baseTokenURI;

    IERC6551Registry erc6551Registry;
    address erc6551AccountImplementation;

    event newPlayer(uint256 tokenId, CharacterSheet);
    event playerRemoved(uint256 tokenId);
    event experienceUpdated(address exp);
    event classAdded(uint256 playerid, uint256 classId);
    event itemAdded(uint256 playerId, uint256 itemTokenId);
    event playerNameUpdated(string oldName, string newName);

    // tokenId => characterSheet
    mapping(uint256 => CharacterSheet) public players;
    //member address => characterSheet token Id.
    mapping(address => uint256) public memberAddressToTokenId;

    uint256 totalSheets;

    constructor() ERC721("CharacterSheet", "CHAS") {
        _disableInitializers();
    }

    modifier onlyExpContract() {
        require(msg.sender == address(_experience), "not the experience contract");
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
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(DUNGEON_MASTER, msg.sender);

        address daoAddress;
        address[] memory dungeonMasters;
        string memory baseUri;
        address experienceImplementation;

        (daoAddress, dungeonMasters, experienceImplementation, baseUri) =
            abi.decode(_encodedParameters, (address, address[], address, string));

        for (uint256 i = 0; i < dungeonMasters.length; i++) {
            _grantRole(DUNGEON_MASTER, dungeonMasters[i]);
            _grantRole(DEFAULT_ADMIN_ROLE, dungeonMasters[i]);
        }

        setBaseUri(baseUri);
        _experience = ExperienceAndItemsImplementation(experienceImplementation);
        _dao = IMolochDAO(daoAddress);
        _tokenIdCounter.increment();
    }

    /**
     *
     * @param _to the address of the dao member wallet that will hold the character sheet nft
     * @param _data encoded data that contains the name of the member and the uri of the base image for the nft.
     * if no uri is stored then it will revert to the base uri of the contract
     */

    function rollCharacterSheet(address _to, bytes calldata _data) public onlyRole(DUNGEON_MASTER) {
        require(
            erc6551AccountImplementation != address(0) && address(erc6551Registry) != address(0),
            "ERC6551 acount implementation and registry not set"
        );

        require(members(_to).shares > 0, "Player is not a member of the dao");

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
            _setTokenURI(tokenId, _baseTokenURI);
        }

        //calculate ERC6551 account address
        address tba = erc6551Registry.account(erc6551AccountImplementation, block.chainid, address(this), tokenId, 0);

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
        emit newPlayer(tokenId, newCharacterSheet);
    }

    function addClassToPlayer(uint256 playerId, uint256 classTokenId) external onlyExpContract {
        players[playerId].classes.push(classTokenId);
        emit classAdded(playerId, classTokenId);
    }

    function removeClassFromPlayer(uint256 playerId, uint256 classTokenId) external onlyExpContract returns(bool success){
        uint256[] memory arr = players[playerId].classes;
        for (uint256 i = 0; i < arr.length; i++) {
            if (arr[i] == classTokenId) {
                for (uint256 j = i; j < arr.length - 1; j++) {
                    arr[j] = arr[j + 1];
                }
                arr[arr.length - 1] = 0;
                players[playerId].classes = arr;
                success = true;
            }
        }
        success = false;
    }

    function addItemToPlayer(uint256 playerId, uint256 itemTokenId) external onlyExpContract {
        players[playerId].items.push(itemTokenId);
        emit itemAdded(playerId, itemTokenId);
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

    function getClassIndex(uint256 playerId, uint256 classId)public view returns(uint256 indexOfClass){
        CharacterSheet memory sheet = players[playerId];
        uint256 length = sheet.classes.length;
        for(uint256 i =0; i<length; i++){
            if(sheet.classes[i] == classId){
                indexOfClass = i;
            }
        }
        revert("this player does not have this class");
    }

    function updateExpContract(address expContract) external onlyRole(DUNGEON_MASTER) {
        _experience = ExperienceAndItemsImplementation(expContract);
        emit experienceUpdated(expContract);
    }

    function members(address _member) public returns (Member memory) {
        return _dao.members(_member);
    }

    function removePlayer(uint256 _tokenId) public onlyRole(DUNGEON_MASTER) {
        require(
            members(getCharacterSheetByPlayerId(_tokenId).memberAddress).jailed > 0,
            "There has been no passing guild kick proposal on this player."
        );
        delete players[_tokenId];
        _burn(_tokenId);
    }

    function renounceSheet(uint256 _playerId) public returns (bool success) {
        require(balanceOf(msg.sender) > 0, "you do not have a characterSheet");
        address tokenOwner = ownerOf(_playerId);
        require(msg.sender == tokenOwner, "You cannot renounce a token you don't own");
        _burn(_playerId);
        success = true;
    }

    function updatePlayerName(string calldata newName) public onlyRole(PLAYER) {
        string memory oldName = players[memberAddressToTokenId[msg.sender]].name;
        players[memberAddressToTokenId[msg.sender]].name = newName;

        emit playerNameUpdated(oldName, newName);
    }

    function setExperienceAndGearContract(address experience) public onlyRole(DUNGEON_MASTER) {
        _experience = ExperienceAndItemsImplementation(experience);
    }

    function setBaseUri(string memory _uri) public onlyRole(DUNGEON_MASTER) {
        _baseTokenURI = _uri;
    }

    // The following functions are overrides required by Solidity.

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    /// @dev Sets the address of the ERC6551 registry
    function setERC6551Registry(address registry) public onlyRole(DUNGEON_MASTER) {
        erc6551Registry = IERC6551Registry(registry);
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
    // solhint-disable-next-line no-unused-vars
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
