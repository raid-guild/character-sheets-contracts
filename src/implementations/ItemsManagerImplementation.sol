// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {UUPSUpgradeable} from "openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
// import {Initializable} from "openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import {MultiToken, Asset} from "../lib/MultiToken.sol";
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

struct RequirementNode {
    uint8 operator; // 0 = nil, 1 = and, 2 = or, 3 = not
    RequirementNode[] children; // if operator is  0, this list must have length 0, else if operator is 3, this list must have length = 1, otherwise it can have any length > 0
    Asset asset; // Asset is non-zero if operator is 0  only
}

struct CraftItem {
    uint256 itemId;
    uint256 amount;
}

error InvalidOperator();
error InvalidAsset();

library RequirementsTree {
    function encode(RequirementNode memory node) internal pure returns (bytes memory requirementTree) {
        bytes[] memory nodes = new bytes[](node.children.length);
        for (uint256 i; i < node.children.length; i++) {
            nodes[i] = encode(node.children[i]);
        }
        return abi.encode(node.operator, node.asset, nodes);
    }

    function encodeFromStorage(RequirementNode storage node) internal view returns (bytes memory requirementTree) {
        bytes[] memory nodes = new bytes[](node.children.length);
        for (uint256 i; i < node.children.length; i++) {
            nodes[i] = encodeFromStorage(node.children[i]);
        }
        return abi.encode(node.operator, node.asset, nodes);
    }

    function decode(bytes memory requirementTree) internal pure returns (RequirementNode memory) {
        uint8 operator;
        Asset memory asset;
        bytes[] memory nodes;

        (operator, asset, nodes) = abi.decode(requirementTree, (uint8, Asset, bytes[]));

        uint256 nodelength = nodes.length;

        RequirementNode memory root =
            RequirementNode({operator: operator, children: new RequirementNode[](nodelength), asset: asset});

        for (uint256 i; i < nodelength; i++) {
            bytes memory node;
            (node) = abi.decode(nodes[i], (bytes));
            root.children[i] = decode(node);
        }

        return root;
    }

    function decodeToStorage(bytes memory requirementTree, RequirementNode storage root) internal {
        bytes[] memory nodes;

        (root.operator, root.asset, nodes) = abi.decode(requirementTree, (uint8, Asset, bytes[]));

        uint256 nodelength = nodes.length;

        // RequirementNode storage root =
        //     RequirementNode({operator: operator, children: new RequirementNode[](nodelength), asset: asset});
        // root.children = new RequirementNode[](nodelength);

        for (uint256 i; i < nodelength; i++) {
            bytes memory node;
            (node) = abi.decode(nodes[i], (bytes));
            // root.children[i] = decode(node);
            decodeToStorage(node, root.children[i]);
        }
    }
}

contract ItemsManagerImplementation is UUPSUpgradeable, ERC1155HolderUpgradeable, ERC721HolderUpgradeable {
    /// @dev clones address storage contract
    IClonesAddressStorage public clones;

    // item claim requirements storage
    /// @dev a tree of requirements for each item
    mapping(uint256 => RequirementNode) internal _claimRequirements;

    // item craft requirements storage
    /// @dev a list of craft items required to craft a new item
    mapping(uint256 => CraftItem[]) internal _craftRequirements;

    event RequirementSet(uint256 itemId, bytes requirements);
    event CraftItemSet(uint256 itemId);
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

        for (uint256 i; i < craftRequirements.length; i++) {
            _craftRequirements[itemId].push(craftRequirements[i]);
        }
        emit CraftItemSet(itemId);
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
        RequirementNode storage requirementTree = _claimRequirements[itemId];
        RequirementsTree.decodeToStorage(requirementTreeBytes, requirementTree);

        emit RequirementSet(itemId, requirementTreeBytes);
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
        if (asset.assetAddress == address(0)) {
            revert InvalidAsset();
        }
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
            if (root.children.length != 0) {
                revert InvalidOperator();
            }
            Asset storage asset = root.asset;

            return checkAsset(characterAccount, amount, asset);
        }
        if (root.operator == 1) {
            // and
            if (root.children.length == 0) {
                revert InvalidOperator();
            }
            bool result = true;
            for (uint256 i; i < root.children.length; i++) {
                RequirementNode storage node = root.children[i];
                result = result && checkClaimRequirements(characterAccount, amount, node);
            }
            return result;
        }
        if (root.operator == 2) {
            // or
            if (root.children.length == 0) {
                revert InvalidOperator();
            }
            bool result = false;
            for (uint256 i; i < root.children.length; i++) {
                RequirementNode storage node = root.children[i];
                result = result || checkClaimRequirements(characterAccount, amount, node);
            }
            return result;
        }
        if (root.operator == 3) {
            // not
            if (root.children.length != 1) {
                revert InvalidOperator();
            }
            return !checkClaimRequirements(characterAccount, amount, root.children[0]);
        }
        revert InvalidOperator();
    }

    //solhint-disable-next-line
    function _authorizeUpgrade(address newImplementation) internal override onlyAdmin {
        //empty block
    }
}
