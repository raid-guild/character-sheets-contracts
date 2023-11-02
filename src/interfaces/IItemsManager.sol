// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Item} from "../lib/Structs.sol";
import {Asset} from "../lib/MultiToken.sol";

interface IItemsManager {
    function craftItem(Item memory item, uint256 itemId, uint256 amount, address caller)
        external
        returns (bool success);

    function dismantleItems(uint256 itemId, uint256 amount, address caller) external returns (bool);

    function addItemRequirement(uint256 itemId, uint8 category, address assetAddress, uint256 assetId, uint256 amount)
        external
        returns (bool success);

    function checkRequirements(address characterAccount, uint256 itemId, uint256 amount) external view returns (bool);

    function getItemRequirements(uint256 itemId) external view returns (Asset[] memory);
}
