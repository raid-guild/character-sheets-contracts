// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "openzeppelin/token/ERC1155/ERC1155.sol";
import "openzeppelin/token/ERC721/IERC721.sol";
import "openzeppelin/token/ERC721/utils/ERC721Holder.sol";
import "openzeppelin/token/ERC1155/utils/ERC1155Receiver.sol";
import "openzeppelin/access/AccessControl.sol";
import "openzeppelin/utils/Counters.sol";

contract MemberCards is ERC1155, AccessControl {
    using Counters for Counters.Counter;

    Counters.Counter private _itemIdCounter;

    bytes32 public constant DUNGEON_MASTER = keccak256("DUNGEON_MASTER");

    bytes4 private constant _INTERFACE_ID_ERC4906 = 0x49064906;
    bytes4 private constant _INTERFACE_ID_ERC2981 = 0x2a55205a;

    //mapping tokenId => item struct for gear
    mapping(uint256 => Item) public items;

    string characterSheetUri;

    struct Item {
        string name;
        uint256 supply;
        string cid;
    }

    constructor() ERC1155("") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(DUNGEON_MASTER, msg.sender);
    }

        
    function setURI(string memory newuri) public onlyRole(DUNGEON_MASTER) {
        _setURI(newuri);
    }

    function dropLoot(address account, uint256 id, uint256 amount, bytes memory data)
        public
        onlyRole(DUNGEON_MASTER)
    {
        _mint(account, id, amount, data);
    }

    function _createLootItemType(string calldata _name, uint256 _supply, string calldata _cid, bytes calldata _data) internal onlyRole(DUNGEON_MASTER){
        Item memory newItemType;
        newItemType.name = _name;
        newItemType.supply = _supply;
        newItemType.cid = _cid;


    }

    function createCharacterSheet(address _member)external onlyRole(DUNGEON_MASTER){

    }

    function increaseStat(uint256 amount) public returns(uint256 stat){

    }

    function _mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
        internal override
        onlyRole(DUNGEON_MASTER)
    {
        _mintBatch(to, ids, amounts, data);
    }

    // The following functions are overrides required by Solidity.

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(AccessControl, ERC1155)
        returns (bool)
    {
                return
            interfaceId == _INTERFACE_ID_ERC4906 ||
            interfaceId == _INTERFACE_ID_ERC2981 ||
            super.supportsInterface(interfaceId);
        
    }

    function setApprovalForAll(address operator, bool approved) public virtual override onlyRole(DUNGEON_MASTER) {
        super._setApprovalForAll(_msgSender(), operator, approved);
    }

}