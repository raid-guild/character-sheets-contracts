// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

struct Item {
    uint256 tokenId; /// @dev erc1155 token id
    uint256 itemId; /// @dev location in the items mapping
    string name; /// @dev the name of this item
    uint256 supply; /// @dev the number of this item to be created.
    uint256 supplied; /// @dev the number of this item that have been given out or claimed
    uint256[][] requirements; /// @dev an array of arrays that are two long containing the required erc1155 tokenId and the amount required eg. [[tokenId, amount], [tokenId, amount]]
    bool soulbound; /// @dev is this item soulbound or not

    /// @dev  claimable: if bytes32(0) then  items are claimable by anyone, otherwise upload a merkle root
    /// of all addresses allowed to claim.  if not claimable at all use any random bytes32(n) besides bytes32(0) so all merkle proofs will fail.
    bytes32 claimable; 
    string cid; /// @dev this item's image/metadata uri
}

struct Class {
    uint256 tokenId; /// @dev erc1155 token id
    uint256 classId; /// @dev location in the classes mapping
    string name; /// @dev class name
    uint256 supply; /// @dev the number of this class that have been minted
    string cid; /// @dev this classes image/metadata uri
}

struct CharacterSheet {
    uint256 tokenId; /// @dev erc721 tokenId
    string name; /// @dev the name of the member who controls this sheet
    address ERC6551TokenAddress; /// @dev the address of the NPC associated with this character sheet
    address memberAddress; /// @dev the EOA of the member who owns this character sheet
    uint256[] classes; /// @dev the classId of the class assigned to this player
    uint256[] inventory;  /// @dev the itemId of the items in this chars inventory
}
