// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "openzeppelin/token/ERC721/ERC721.sol";
import "openzeppelin/token/ERC721/extensions/ERC721URIStorage.sol";
import "openzeppelin/access/AccessControl.sol";
import "openzeppelin/utils/Counters.sol";
import "./interfaces/IERC6551Registry.sol";

contract CharacterSheets is ERC721, ERC721URIStorage, AccessControl {
    using Counters for Counters.Counter;
    bytes32 public constant DUNGEON_MASTER = keccak256("DUNGEON_MASTER");
    Counters.Counter private _tokenIdCounter;

    IERC6551Registry erc6551Registry;
    address erc6551AccountImplementation;

    event newPlayer(uint256 tokenId, address ERC6551Address);

    constructor() ERC721("CharacterSheet", "CHAS") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(DUNGEON_MASTER, msg.sender);
    }
    // tokenId => characterSheet
    mapping(uint256 => CharacterSheet) public players;

    struct CharacterSheet {
        string name;
        mapping(class => bool) classes;
        address ERC6551TokenAddress;
    }

    enum class {WIZARD, WARRIOR, BARD, ROGUE, MONK, ARCHER, TAVERN_KEEPER, RANGER, SCRIBE, PALADIN, NECROMANCER}

    function rollCharacterSheet(address _to, string calldata _uri, bytes calldata _data) public onlyRole(DUNGEON_MASTER) returns(CharacterSheet memory) {
        string memory newName;
        uint256[] memory newClasses;
        (newName, newClasses) = abi.decode(_data, (string, uint256[]));
        require(erc6551AccountImplementation != address(0) && address(erc6551Registry) != address(0), "ERC6551 acount implementation and registry not set");
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(_to, tokenId);
        _setTokenURI(tokenId, _uri);

           // calculate ERC6551 account address
            address tba = erc6551Registry.account(
                erc6551AccountImplementation,
                block.chainid,
                address(this),
                tokenId,
                0
            );

        CharacterSheet memory newCharacterSheet;
        newCharacterSheet.name = newName;
        uint256 i;
        //#TODO fix this bullshit.
        while(i < newClasses.length ){
            class = class.newClasses[i];
            newCharacterSheet.classes[class] = true;
            i++;
        }
        newCharacterSheet.classes = newClasses;
        newCharacterSheet.ERC6551TokenAddress = tba;

        players[tokenId] = newCharacterSheet;

        emit newPlayer(tokenId, tba);

        return newCharacterSheet;
    }

    // The following functions are overrides required by Solidity.

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }



    /// @dev Sets the address of the ERC6551 registry
    function setERC6551Registry(address registry)
        public
        onlyRole(DUNGEON_MASTER)
    {
        erc6551Registry = IERC6551Registry(registry);
    }

    /// @dev Sets the address of the ERC6551 account implementation
    function setERC6551Implementation(address implementation)
        public
        onlyRole(DUNGEON_MASTER)
    {
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