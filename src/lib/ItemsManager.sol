// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Errors} from "../lib/Errors.sol";
import {MultiToken, Asset, Category} from "../lib/MultiToken.sol";
import "./Structs.sol";

// import "forge-std/console2.sol";  //remove for launch

contract ItemsManager {
    /// @dev stores the items used in crafting at the time the item was crafted.
    /// character => itemId => receipts Assets used in crafting
    mapping(address => mapping(uint256 => Receipt[])) internal _craftingReceipts;

    //temporary array for refund calulations
    Asset[] internal _currentRefunds;

    /// @dev address of the classes contract for item requirements check
    address public classesContract;

    // item requirements storage
    /// @dev an array of requirements to transfer this item
    mapping(uint256 => Asset[]) internal _requirements;

    event RequirementAdded(uint256 itemId, uint8 category, address assetAddress, uint256 assetId, uint256 amount);
    event RequirementRemoved(uint256 itemId, address assetAddress, uint256 assetId);

    function getReceipts(address account, uint256 itemId) public view returns (Receipt[] memory) {
        return _craftingReceipts[account][itemId];
    }

    /**
     * @notice Checks the item requirements to create a new item then transfers the requirements in the character's inventory to this contract to create the new item
     * @dev Explain to a developer any extra details
     * @param itemId the itemId of the item to be crafted
     * @param amount the number of new items to be created
     * @return success bool if crafting is a success return true, else return false
     */

    function _craftItem(Item memory item, uint256 itemId, Asset[] memory itemRequirements, uint256 amount)
        internal
        returns (bool success)
    {
        if (!item.craftable) {
            revert Errors.ItemError();
        }
        Asset memory newRequirement;
        for (uint256 i; i < itemRequirements.length; i++) {
            newRequirement = itemRequirements[i];
            //if required item is a class skip token transfer
            if (newRequirement.assetAddress != classesContract) {
                //issue crafting receipt before amounts change
                _craftingReceipts[msg.sender][itemId].push(
                    Receipt({
                        category: newRequirement.category,
                        assetAddress: newRequirement.assetAddress,
                        assetId: newRequirement.id,
                        amountCrafted: amount,
                        amountRequired: newRequirement.amount
                    })
                );

                //add asset amounts
                newRequirement.amount = newRequirement.amount * amount;

                //transfer assets to this contract must have approval
                MultiToken.safeTransferAssetFrom(newRequirement, msg.sender, address(this));
            }
        }

        success = true;
        return success;
    }

    //TODO gas optimize this function.  3 loops in one function is incredibly inefficient.
    function _dismantleItems(uint256 itemId, uint256 amount) internal returns (bool) {
        Receipt[] storage receipts = _craftingReceipts[msg.sender][itemId];
        //check crafted items array if any assets exist
        if (receipts.length == 0) {
            revert Errors.ItemError();
        }
        Asset memory refund;
        for (uint256 i; i < receipts.length; i++) {
            (receipts[i], refund) = _calculateRefund(receipts[i], amount);

            // add refund to refunds array
            _currentRefunds.push(refund);
        }
        Receipt memory currentReceipt;
        for (uint256 i; i < receipts.length; i++) {
            // clean up array
            if (receipts[i].amountCrafted == 0) {
                currentReceipt = receipts[i];
                //move to end of array
                receipts[i] = receipts[receipts.length - 1];

                receipts[receipts.length - 1] = currentReceipt;
                //pop from array
                receipts.pop();
            }
        }
        /// refund assets
        for (uint256 i; i < _currentRefunds.length; i++) {
            MultiToken.safeTransferAssetFrom(_currentRefunds[i], address(this), msg.sender);
        }

        delete _currentRefunds;

        return true;
    }

    function _addItemRequirement(uint256 itemId, uint8 category, address assetAddress, uint256 assetId, uint256 amount)
        internal
        returns (bool success)
    {
        Asset memory newRequirement =
            Asset({category: Category(category), assetAddress: assetAddress, id: assetId, amount: amount});

        _requirements[itemId].push(newRequirement);
        success = true;

        emit RequirementAdded(itemId, category, assetAddress, assetId, amount);
        return success;
    }

    function _removeItemRequirement(uint256 itemId, address assetAddress, uint256 assetId) internal returns (bool) {
        Asset[] storage arr = _requirements[itemId];
        bool success = false;
        for (uint256 i; i < arr.length; i++) {
            Asset storage asset = arr[i];
            if (asset.assetAddress == assetAddress && asset.id == assetId) {
                for (uint256 j = i; j < arr.length; j++) {
                    if (j + 1 < arr.length) {
                        arr[j] = arr[j + 1];
                    } else if (j + 1 >= arr.length) {
                        arr[j] = MultiToken.ERC20(address(0), 0);
                    }
                }
                success = true;
            }
        }

        if (success == true) {
            _requirements[itemId] = arr;
            _requirements[itemId].pop();
        } else {
            revert Errors.ItemError();
        }

        emit RequirementRemoved(itemId, assetAddress, assetId);

        return success;
    }

    function _checkRequirements(address characterAccount, uint256 itemId, uint256 amount)
        internal
        view
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
            if (newRequirement.assetAddress == classesContract) {
                if (balance < newRequirement.amount) {
                    return false;
                }
            } else if (balance < newRequirement.amount * amount) {
                return false;
            }
        }
        return true;
    }

    function _calculateRefund(Receipt memory latestReceipt, uint256 amount)
        private
        pure
        returns (Receipt memory, Asset memory refund)
    {
        //TODO think of a way to do this so you can refund more than the amount in each receipt.
        // eg;  craft 2 items with x requirements and 2 of the same item with y requirements.
        // dismantle 3 and get 2 with y requirements and 1 with x refunded;
        if (amount <= latestReceipt.amountCrafted) {
            refund = Asset({
                category: latestReceipt.category,
                assetAddress: latestReceipt.assetAddress,
                id: latestReceipt.assetId,
                amount: amount * latestReceipt.amountRequired
            });
            latestReceipt.amountCrafted -= amount;
        } else {
            revert Errors.InsufficientBalance();
        }

        return (latestReceipt, refund);
    }
}
