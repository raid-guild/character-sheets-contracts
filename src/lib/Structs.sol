// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Asset} from "./MultiToken.sol";

struct Item {
    /// @dev  claimable: if bytes32(0) then  items are claimable by anyone, otherwise upload a merkle root
    /// of all addresses allowed to claim.  if not claimable at all use any random bytes32(n) besides bytes32(0)
    /// so all merkle proofs will fail.
    bytes32 claimable;
    /// @dev whether or not this item is craftable
    bool craftable;
    /// @dev is this item soulbound or not
    bool soulbound;
    /// @dev the number of this item that have been given out or claimed
    uint256 supplied;
    /// @dev the number of this item to be created.
    uint256 supply;
}

struct Class {
    /// @dev erc1155 token id
    uint256 tokenId;
    /// @dev the number of this class that have been minted
    uint256 supply;
    /// @dev set to true if you want characters to be able to claim this class instead of being assined
    bool claimable;
    /// @dev this classes image/metadata uri
    string cid;
}

struct CharacterSheet {
    /// @dev erc721 tokenId
    uint256 tokenId;
    /// @dev the name of the member who controls this sheet
    string name;
    /// @dev the address of the NPC associated with this character sheet
    address erc6551TokenAddress;
    /// @dev the EOA of the member who owns this character sheet
    address memberAddress;
    /// @dev the itemId of the equipped items in this chars inventory
    uint256[] inventory;
}
