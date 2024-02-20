// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {UUPSUpgradeable} from "openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
// import {Initializable} from "openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import {MultiToken, Asset, Category} from "../lib/MultiToken.sol";
import {IHatsAdaptor} from "../interfaces/IHatsAdaptor.sol";
import {IItems} from "../interfaces/IItems.sol";
//solhint-disable-next-line
import "../lib/Structs.sol";
import {Errors} from "../lib/Errors.sol";

import {ERC1155HolderUpgradeable} from
    "openzeppelin-contracts-upgradeable/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";
import {ERC721HolderUpgradeable} from
    "openzeppelin-contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol";

import {IClonesAddressStorage} from "../interfaces/IClonesAddressStorage.sol";

// import "forge-std/console2.sol";  //remove for launch

contract ItemsManagerImplementation is UUPSUpgradeable, ERC1155HolderUpgradeable, ERC721HolderUpgradeable {
    /// @dev clones address storage contract
    IClonesAddressStorage public clones;

    // item requirements storage
    /// @dev an array of requirements to transfer this item
    mapping(uint256 => Asset[]) internal _requirements;

    event RequirementAdded(uint256 itemId, uint8 category, address assetAddress, uint256 assetId, uint256 amount);
    // event RequirementRemoved(uint256 itemId, address assetAddress, uint256 assetId);
    event ItemsDismantled(uint256 itemId, uint256 amount, address caller);

    modifier onlyItemsContract() {
        if (msg.sender != clones.items()) {
            revert Errors.ItemError();
        }
        _;
    }

    modifier onlyGameMaster() {
        if (!IHatsAdaptor(clones.hatsAdaptor()).isGameMaster(msg.sender)) {
            revert Errors.GameMasterOnly();
        }
        _;
    }

    modifier onlyAdmin() {
        if (!IHatsAdaptor(clones.hatsAdaptor()).isAdmin(msg.sender)) {
            revert Errors.AdminOnly();
        }
        _;
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(address clonesAddressStorage) external initializer {
        __UUPSUpgradeable_init();
        __ERC1155Holder_init();
        clones = IClonesAddressStorage(clonesAddressStorage);
    }

    /**
     * @notice Checks the item requirements to create a new item then transfers the requirements in the character's inventory to this contract to create the new item
     * @dev Explain to a developer any extra details
     * @param itemId the itemId of the item to be crafted
     * @param amount the number of new items to be created
     * @return success bool if crafting is a success return true, else return false
     */
    function craftItem(Item memory item, uint256 itemId, uint256 amount, address caller)
        public
        onlyItemsContract
        returns (bool success)
    {
        if (!item.craftable) {
            revert Errors.ItemError();
        }

        Asset memory newRequirement;
        for (uint256 i; i < _requirements[itemId].length; i++) {
            newRequirement = _requirements[itemId][i];
            //if required item is a class skip token transfer  TODO add, if this is a soulbound token.
            if (newRequirement.assetAddress != clones.classes()) {
                //add asset amounts
                newRequirement.amount = newRequirement.amount * amount;

                //transfer assets to this contract must have approval
                MultiToken.safeTransferAssetFrom(newRequirement, caller, address(this));
            }
        }

        success = true;
        return success;
    }

    function dismantleItems(uint256 itemId, uint256 amount, address caller) public onlyItemsContract returns (bool) {
        if (IItems(clones.items()).balanceOf(caller, itemId) < amount) {
            revert Errors.InsufficientBalance();
        }
        Asset memory requirement;
        for (uint256 i; i < _requirements[itemId].length; i++) {
            requirement = _requirements[itemId][i];
            if (requirement.assetAddress != address(clones.classes())) {
                Asset memory refund = _calculateRefund(_requirements[itemId][i], amount);
                if (MultiToken.balanceOf(requirement, address(this)) < refund.amount) {
                    return false;
                }
                // transfer token
                MultiToken.safeTransferAssetFrom(refund, address(this), caller);
            }
        }
        emit ItemsDismantled(itemId, amount, caller);
        return true;
    }

    function addItemRequirement(uint256 itemId, uint8 category, address assetAddress, uint256 assetId, uint256 amount)
        public
        onlyItemsContract
        returns (bool success)
    {
        Asset memory newRequirement =
            Asset({category: Category(category), assetAddress: assetAddress, id: assetId, amount: amount});

        _requirements[itemId].push(newRequirement);
        success = true;

        emit RequirementAdded(itemId, category, assetAddress, assetId, amount);
        return success;
    }

    function checkRequirements(address characterAccount, uint256 itemId, uint256 amount)
        public
        view
        onlyItemsContract
        returns (bool)
    {
        Asset[] storage itemRequirements = _requirements[itemId];
        if (itemRequirements.length == 0) {
            return true;
        }

        Asset storage newRequirement;

        for (uint256 i; i < itemRequirements.length; i++) {
            newRequirement = itemRequirements[i];

            uint256 balance = MultiToken.balanceOf(newRequirement, characterAccount);

            // if the required asset is a class check that the balance is not less than the required level.
            if (newRequirement.assetAddress == clones.classes()) {
                if (balance < newRequirement.amount) {
                    return false;
                }
            } else if (balance < newRequirement.amount * amount) {
                return false;
            }
        }
        return true;
    }

    function getItemRequirements(uint256 itemId) public view returns (Asset[] memory) {
        return _requirements[itemId];
    }

    //solhint-disable-next-line
    function _authorizeUpgrade(address newImplementation) internal override onlyAdmin {
        //empty block
    }

    function _calculateRefund(Asset memory requirement, uint256 amount) private pure returns (Asset memory refund) {
        refund = Asset({
            category: requirement.category,
            assetAddress: requirement.assetAddress,
            id: requirement.id,
            amount: amount * requirement.amount
        });

        return refund;
    }
}
