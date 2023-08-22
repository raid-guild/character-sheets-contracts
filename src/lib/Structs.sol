// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


struct Item {
    /// @dev erc1155 token id
    uint256 tokenId; 
    /// @dev location in the items mapping
    uint256 itemId; 
    /// @dev the name of this item
    string name; 
    /// @dev the number of this item to be created.
    uint256 supply; 
    /// @dev the number of this item that have been given out or claimed
    uint256 supplied; 
    /// @dev an array of arrays with length of 2. containing the required itemId and the amount required 
    /// eg. [[itemId, amount], [itemId, amount]]
    uint256[][] requirements;
    /// @dev is this item soulbound or not
    bool soulbound; 

    /// @dev  claimable: if bytes32(0) then  items are claimable by anyone, otherwise upload a merkle root
    /// of all addresses allowed to claim.  if not claimable at all use any random bytes32(n) besides bytes32(0)
    /// so all merkle proofs will fail.
    bytes32 claimable; 
    /// @dev this item's image/metadata uri
    string cid; 
}

struct Class {
    /// @dev erc1155 token id
    uint256 tokenId;
    /// @dev location in the classes mapping 
    uint256 classId; 
    /// @dev class name
    string name; 
    /// @dev the number of this class that have been minted
    uint256 supply; 
    /// @dev this classes image/metadata uri
    string cid; 
}

struct CharacterSheet {
    /// @dev erc721 tokenId
    uint256 tokenId; 
    /// @dev the name of the member who controls this sheet
    string name; 
    /// @dev the address of the NPC associated with this character sheet
    address ERC6551TokenAddress; 
    /// @dev the EOA of the member who owns this character sheet
    address memberAddress; 
    /// @dev the classId of the class equipped to this player
    uint256[] classes; 
    /// @dev the itemId of the equipped items in this chars inventory
    uint256[] inventory;  
}
