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

    struct CharacterSheet {
        string name;
        address ERC6551TokenAddress;
        address memberAddress;
        uint256[] classes;
        uint256[] items;
    }

contract CharacterSheetsImplementation is
    Initializable,
    IMolochDAO,
    ERC721,
    ERC721URIStorage,
    AccessControl
{
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;

    bytes32 public constant DUNGEON_MASTER = keccak256("DUNGEON_MASTER");
    bytes32 public constant PLAYER = keccak256("PLAYER");
    bytes32 public constant NPC = keccak256("NPC");

    ExperienceAndItemsImplementation _experience;

    IMolochDAO internal _dao;

    address private _gearAndAttributesContract;

    string private _baseTokenURI;

    IERC6551Registry erc6551Registry;
    address erc6551AccountImplementation;

    event newPlayer(uint256 tokenId, CharacterSheet);
    event playerRemoved(uint256 tokenId);

    // tokenId => characterSheet
    mapping(uint256 => CharacterSheet) public players;
    //member address => characterSheet token Id.
    mapping(address => uint256) public memberAddressToTokenId;

    uint256 totalSheets;

    constructor() ERC721("CharacterSheet", "CHAS") {
        _disableInitializers();
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

        
        for(uint256 i = 0; i<dungeonMasters.length; i++){
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

        require(players[tokenId].ERC6551TokenAddress == address(0x0), "this player is already in the game");

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
        //store info in mappings
        players[tokenId] = newCharacterSheet;
        memberAddressToTokenId[_to] = tokenId;

        totalSheets++;
        _grantRole(PLAYER, _to);
        _grantRole(NPC, tba);
        emit newPlayer(tokenId, newCharacterSheet);
    }

    function getCharacterSheetByPlayerId(uint256 tokenId) public view returns (CharacterSheet memory) {
        require(players[tokenId].memberAddress > address(0), "This is not a character.");
        return players[tokenId];
    }

    function getPlayerIdByMemberAddress(address _memberAddress) public view returns (uint256) {
        require(memberAddressToTokenId[_memberAddress] > 0, "This member is not a player character.");
        return memberAddressToTokenId[_memberAddress];
    }

    function getMemberByPlayerId(uint256 _playerId) public view returns (address) {
        return players[_playerId].memberAddress;
    }

   
    function getPlayerIdByNftAddress(address _nftAddress) public view returns (uint256) {
        for (uint256 i = 1; i <= totalSheets; i++) {
            if (players[i].ERC6551TokenAddress == _nftAddress) {
                return i;
            }
        }
        revert("NOT AN NPC");
    }

    function getNftAddressByPlayerId(uint256 playerId)public view returns (address){
        require(players[playerId].memberAddress > address(0), "not a player");
        return players[playerId].ERC6551TokenAddress;
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
    function approve(address to, uint256 tokenId) public virtual override(ERC721, IERC721){
        revert("This token can only be approved by the dungeon master");
    }
    
        /**
     * @dev See {IERC721-setApprovalForAll}.
     */
    function setApprovalForAll(address operator, bool approved) public virtual override(ERC721, IERC721){
       revert("This token can only be transfered by the dungeon master");
    }

     /**
     * @dev See {IERC721-transferFrom}.
     */
    function transferFrom(address from, address to, uint256 tokenId) public virtual override(ERC721, IERC721) onlyRole(DUNGEON_MASTER){
            _transfer(from, to, tokenId);
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(address from, address to, uint256 tokenId) public virtual override(ERC721, IERC721) onlyRole(DUNGEON_MASTER) {
        safeTransferFrom(from, to, tokenId, "");
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public virtual override(ERC721, IERC721) onlyRole(DUNGEON_MASTER) {
        _safeTransfer(from, to, tokenId, data);
    }

    function renounceSheet(uint256 _playerId)public returns(bool success){
        address tokenOwner = ownerOf(_playerId);
        require(msg.sender == tokenOwner, "You cannot renounce a token you don't own");
        _burn(_playerId);
        success = true;
    }
}
