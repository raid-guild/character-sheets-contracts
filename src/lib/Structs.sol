// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

struct Item {
    uint256 tokenId; //erc1155 token id
    uint256 itemId; //location in the items mapping
    string name; // the name of this item
    uint256 supply; // the number of this item to be created.
    uint256 supplied; // the number of this item that have been given out or claimed
    ItemRequirement[] requirements; // the amount of whatever items are required to claim this item.
    uint256 hatId; // the id of the hat that is associated with this item.  (not implemented yet)
    bool soulbound; // is this item soulbound or not

    //  claimable: if bytes32(0) then  items are claimable by anyone, otherwise upload a merkle root
    // of all addresses allowed to claim.  if not claimable at all use any random bytes32(n) besides bytes32(0) so all merkle proofs will fail.
    bytes32 claimable; 
    string cid; // this item's image/metadata uri
}

struct ItemRequirement {
    uint256 tokenId;
    uint256 amount;
}

struct Class {
    uint256 tokenId; // erc1155 token id
    uint256 classId; // location in the classes mapping
    string name; // class name
    uint256 supply; // the number of this class that have been minted
    string cid; // this classes image/metadata uri
}

struct CharacterSheet {
    uint256 tokenId; // erc721 tokenId
    string name; // the name of the member who controls this sheet
    address ERC6551TokenAddress; // the address of the NPC associated with this character sheet
    address memberAddress; // the EOA of the member who owns this character sheet
    uint256[] classes; // the classId of the class assigned to this player
    uint256[] inventory;  // the itemId of the items in this chars inventory
}
