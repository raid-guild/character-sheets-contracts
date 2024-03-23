// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {UUPSUpgradeable} from "openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {MultiToken, Asset} from "../lib/MultiToken.sol";
import {IHatsAdaptor} from "../interfaces/IHatsAdaptor.sol";
import {IItems} from "../interfaces/IItems.sol";

//solhint-disable-next-line
import "../lib/Structs.sol";
import {Errors} from "../lib/Errors.sol";
import {RequirementsTree} from "../lib/RequirementsTree.sol";

import {ERC1155HolderUpgradeable} from
    "openzeppelin-contracts-upgradeable/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";
import {ERC721HolderUpgradeable} from
    "openzeppelin-contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol";

import {IClonesAddressStorage} from "../interfaces/IClonesAddressStorage.sol";

// import "forge-std/console2.sol"; //remove for launch

contract ItemsManagerImplementation is UUPSUpgradeable, ERC1155HolderUpgradeable, ERC721HolderUpgradeable {
    /// @dev clones address storage contract
    IClonesAddressStorage public clones;

    // item claim requirements storage
    /// @dev a tree of requirements for each item
    mapping(uint256 => RequirementNode) internal _claimRequirements;

    // item craft requirements storage
    /// @dev a list of craft items required to craft a new item
    mapping(uint256 => CraftItem[]) internal _craftRequirements;

    event ClaimRequirementsSet(uint256 itemId, bytes requirementsBytes);
    event CraftRequirementsSet(uint256 itemId, bytes requirementsBytes);
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

    function setCraftRequirements(uint256 itemId, bytes calldata craftRequirementsBytes) public onlyItemsContract {
        CraftItem[] memory craftRequirements;
        (craftRequirements) = abi.decode(craftRequirementsBytes, (CraftItem[]));

        delete _craftRequirements[itemId];

        uint256 lastItemId = 0;
        for (uint256 i; i < craftRequirements.length; i++) {
            if (craftRequirements[i].itemId == itemId) {
                revert Errors.CraftItemError();
            }
            if (i != 0 && craftRequirements[i].itemId <= lastItemId) {
                revert Errors.CraftItemError();
            }
            lastItemId = craftRequirements[i].itemId;
            _craftRequirements[itemId].push(craftRequirements[i]);
        }
        emit CraftRequirementsSet(itemId, craftRequirementsBytes);
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

        CraftItem storage requirement;
        for (uint256 i; i < _craftRequirements[itemId].length; i++) {
            requirement = _craftRequirements[itemId][i];
            uint256 requiredAmount = requirement.amount * amount;

            if (IItems(clones.items()).balanceOf(caller, requirement.itemId) < requiredAmount) {
                revert Errors.InsufficientBalance();
            }

            //transfer assets to this contract must have approval
            IItems(clones.items()).safeTransferFrom(caller, address(this), requirement.itemId, requiredAmount, "");
        }

        success = true;
        return success;
    }

    function dismantleItems(uint256 itemId, uint256 amount, address caller) public onlyItemsContract returns (bool) {
        if (IItems(clones.items()).balanceOf(caller, itemId) < amount) {
            revert Errors.InsufficientBalance();
        }
        CraftItem storage requirement;
        for (uint256 i; i < _craftRequirements[itemId].length; i++) {
            requirement = _craftRequirements[itemId][i];
            uint256 refundAmount = requirement.amount * amount;
            if (IItems(clones.items()).balanceOf(address(this), requirement.itemId) < refundAmount) {
                revert Errors.InsufficientBalance();
            }

            IItems(clones.items()).safeTransferFrom(address(this), caller, requirement.itemId, refundAmount, "");
        }
        emit ItemsDismantled(itemId, amount, caller);
        return true;
    }

    function setClaimRequirements(uint256 itemId, bytes calldata requirementTreeBytes) public onlyItemsContract {
        delete _claimRequirements[itemId];
        RequirementNode storage requirementTree = _claimRequirements[itemId];
        RequirementsTree.decodeToStorage(requirementTreeBytes, requirementTree);
        RequirementsTree.validateTreeInStorage(requirementTree);

        emit ClaimRequirementsSet(itemId, requirementTreeBytes);
    }

    function checkClaimRequirements(address characterAccount, uint256 itemId, uint256 amount)
        public
        view
        onlyItemsContract
        returns (bool)
    {
        RequirementNode storage root = _claimRequirements[itemId];
        if (root.operator == 0 && root.children.length == 0 && root.asset.assetAddress == address(0)) {
            return true;
        }
        return checkClaimRequirements(characterAccount, amount, root);
    }

    function getClaimRequirements(uint256 itemId) public view returns (bytes memory requirementTreeBytes) {
        bytes memory encoded = RequirementsTree.encodeFromStorage(_claimRequirements[itemId]);
        return encoded;
    }

    function getCraftRequirements(uint256 itemId) public view returns (bytes memory requirementTreeBytes) {
        CraftItem[] storage craftRequirements = _craftRequirements[itemId];
        bytes memory encoded = abi.encode(craftRequirements);
        return encoded;
    }

    function checkAsset(address characterAccount, uint256 amount, Asset storage asset) internal view returns (bool) {
        uint256 balance = MultiToken.balanceOf(asset, characterAccount);

        // if the required asset is a class check that the balance is not less than the required level.
        if (asset.assetAddress == clones.classes()) {
            if (balance < asset.amount) {
                return false;
            }
        } else if (balance < asset.amount * amount) {
            return false;
        }
        return true;
    }

    function checkClaimRequirements(address characterAccount, uint256 amount, RequirementNode storage root)
        internal
        view
        returns (bool)
    {
        if (root.operator == 0) {
            // leaf node
            return checkAsset(characterAccount, amount, root.asset);
        }
        if (root.operator == 1) {
            // and
            bool result = true;
            for (uint256 i; i < root.children.length; i++) {
                result = result && checkClaimRequirements(characterAccount, amount, root.children[i]);
            }
            return result;
        }
        if (root.operator == 2) {
            // or
            bool result = false;
            for (uint256 i; i < root.children.length; i++) {
                result = result || checkClaimRequirements(characterAccount, amount, root.children[i]);
            }
            return result;
        }
        if (root.operator == 3) {
            // not
            if (root.children.length == 1 && root.asset.assetAddress == address(0)) {
                return !checkClaimRequirements(characterAccount, amount, root.children[0]);
            }
            if (root.children.length == 0 && root.asset.assetAddress != address(0)) {
                return !checkAsset(characterAccount, amount, root.asset);
            }
            return false;
        }
        return false;
    }

    //solhint-disable-next-line
    function _authorizeUpgrade(address newImplementation) internal override onlyAdmin {
        //empty block
    }
}
