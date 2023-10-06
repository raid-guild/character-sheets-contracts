// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

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
    /// @dev the number of this class that have been minted
    uint256 supply;
    /// @dev set to true if you want characters to be able to claim this class instead of being assined
    bool claimable;
}

struct CharacterSheet {
    /// @dev the address of the player who owns this character sheet
    address playerAddress;
    /// @dev the address of the erc6551 account associated with this character sheet
    address accountAddress;
    /// @dev the itemId of the equipped items in this chars inventory
    uint256[] inventory;
}

struct HatsData {
    /// @dev the address of the hats contract
    address hats;
    /// @dev the address of the hatsModuleFactory
    address hatsModuleFactory;
    /// @dev the adress of the eligibility module for the Hats admins.
    address adminHatEligibilityModuleImplementation;
    /// @dev the address of the dungeonMasterEligibilityModule
    address dungeonMasterHatEligibilityModuleImplementation;
    /// @dev the address of the character hats eligibility module deployed from the hats module factory
    address characterHatEligibilityModuleImplementation;
    /// @dev the address of the player hats eligibility module deployed from the hats module factory
    address playerHatEligibilityModuleImplementation;
    /// @dev uint256 id of top hat
    uint256 topHatId;
    /// @dev the uint256 hat id of the admin hat
    uint256 adminHatId;
    /// @dev the uint256 id of the dungeonMaster hat
    uint256 dungeonMasterHatId;
    /// @dev the uint256 hat id of the player hat
    uint256 playerHatId;
    /// @dev the uint256 hat id of the character hat
    uint256 characterHatId;
}
