// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
pragma abicoder v2;

import "openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import "openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "openzeppelin-contracts/contracts/access/AccessControl.sol";
import "openzeppelin-contracts/contracts/utils/Counters.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "./interfaces/IERC6551Registry.sol";
import "./interfaces/IMolochDAO.sol";
import "forge-std/console2.sol";

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

    IMolochDAO internal _dao;

    IERC6551Registry erc6551Registry;
    address erc6551AccountImplementation;

    event newPlayer(uint256 tokenId, CharacterSheet);
    event playerRemoved(uint256 tokenId);

    string internal maleBaseImageURI;
    string internal femaleBaseImageURI;

    struct CharacterSheet {
        string name;
        address ERC6551TokenAddress;
        address playerAddress;
    }

    constructor() ERC721("CharacterSheet", "CHAS"){
        _disableInitializers();
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(DUNGEON_MASTER, msg.sender);
        _tokenIdCounter.increment();
    }

    function initialize(bytes calldata _encodedParameters) public initializer {
        address daoAddress;
        address dungeonMaster;
        (daoAddress, dungeonMaster) = abi.decode(_encodedParameters,(address, address));
        _dao = IMolochDAO(daoAddress);  
        _grantRole(DEFAULT_ADMIN_ROLE, dungeonMaster);
        _grantRole(DUNGEON_MASTER, dungeonMaster);
    }


    // tokenId => characterSheet
    mapping(uint256 => CharacterSheet) public players;

    function rollCharacterSheet(address _to, bytes calldata _data) public onlyRole(DUNGEON_MASTER) {
        require(
            erc6551AccountImplementation != address(0) && address(erc6551Registry) != address(0),
            "ERC6551 acount implementation and registry not set"
        );

        Member memory newMember = members(_to);
        require(newMember.shares > 0, "player is not a member of the dao");

        string memory newName;
        bool female;
        (newName, female) = abi.decode(_data, (string, bool));
        string memory _uri;

        if (female) {
            _uri = femaleBaseImageURI;
        } else {
            _uri = maleBaseImageURI;
        }

        uint256 tokenId = _tokenIdCounter.current();

        require(players[tokenId].ERC6551TokenAddress == address(0x0), "this player is already in the game");

        _tokenIdCounter.increment();
        _safeMint(_to, tokenId);

        //calculate ERC6551 account address
        address tba = erc6551Registry.account(erc6551AccountImplementation, block.chainid, address(this), tokenId, 0);

        CharacterSheet memory newCharacterSheet;
        newCharacterSheet.name = newName;
        newCharacterSheet.ERC6551TokenAddress = tba;
        newCharacterSheet.playerAddress = _to;
        players[tokenId] = newCharacterSheet;

        emit newPlayer(tokenId, newCharacterSheet);
    }
    function members(address _member)public returns(Member memory){
        return _dao.members(_member);
    }
    function removePlayer(uint256 _tokenId) public onlyRole(DUNGEON_MASTER) {
        delete players[_tokenId];
        _burn(_tokenId);
    }
    // The following functions are overrides required by Solidity.

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

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
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
}
