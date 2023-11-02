// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Category, Asset} from "./MultiToken.sol";

struct ClonesAddresses {
    address characterSheets;
    address items;
    address itemsManager;
    address classes;
    address experience;
    address characterEligibilityAdaptor;
    address classLevelAdaptor;
    address hatsAdaptor;
}

struct Item {
    /// @dev  claimable: if bytes32(0) then  items are claimable by anyone, otherwise upload a merkle root
    /// of all addresses allowed to claim.  if not claimable at all use any random bytes32(n) besides bytes32(0)
    /// so all merkle proofs will fail.
    bytes32 claimable;
    /// @dev if this item is claimable the distribution is the number of times this item can be claimed using the same merkle root.
    // or if clamable is set to bytes32(0) then distribution will be the number of items that can be claimed.
    uint256 distribution;
    /// @dev whether or not this item is craftable
    bool craftable;
    /// @dev is this item soulbound or not
    bool soulbound;
    /// @dev the number of this item that have been given out or claimed
    uint256 supplied;
    /// @dev the number of this item to be created.
    uint256 supply;
    ///@dev true by default.  set to false if this item is to be disabled in the UI
    bool enabled;
}

struct Receipt {
    Category category;
    address assetAddress;
    uint256 assetId;
    uint256 amountCrafted;
    uint256 amountRequired;
}

struct Class {
    /// @dev the number of this class that have been minted
    uint256 supply;
    /// @dev set to true if you want characters to be able to claim this class instead of being assined
    bool claimable;
}

// enum Category {
//     ERC20,
//     ERC721,
//     ERC1155
// }

struct CharacterSheet {
    /// @dev the address of the player who owns this character sheet
    address playerAddress;
    /// @dev the address of the erc6551 account associated with this character sheet
    address accountAddress;
    /// @dev the itemId of the equipped items in this chars inventory
    uint256[] inventory;
}

struct HatsData {
    /// @dev uint256 id of top hat
    uint256 topHatId;
    /// @dev the uint256 hat id of the admin hat
    uint256 adminHatId;
    /// @dev the uint256 id of the gameMaster hat
    uint256 gameMasterHatId;
    /// @dev the uint256 hat id of the player hat
    uint256 playerHatId;
    /// @dev the uint256 hat id of the character hat
    uint256 characterHatId;
}

struct ImplementationAddresses {
    // implementation addresses
    address characterSheetsImplementation;
    address itemsImplementation;
    address itemsManagerImplementation;
    address classesImplementation;
    address erc6551Registry;
    address erc6551AccountImplementation;
    address experienceImplementation;
    address cloneAddressStorage;
    //hats addresses
    address hatsContract;
    address hatsModuleFactory;
    //eligibility modules
    address adminHatsEligibilityModule;
    address gameMasterHatsEligibilityModule;
    address playerHatsEligibilityModule;
    address characterHatsEligibilityModule;
}

struct AdaptorImplementations {
    address characterEligibilityAdaptorV2Implementation;
    address characterEligibilityAdaptorV3Implementation;
    address classLevelAdaptorImplementation;
    address hatsAdaptorImplementation;
}
