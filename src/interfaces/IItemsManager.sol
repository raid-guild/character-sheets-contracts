// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Item} from "../lib/Structs.sol";

interface IItemsManager {
    function craftItem(Item memory item, uint256 itemId, uint256 amount, address caller)
        external
        returns (bool success);

    function dismantleItems(uint256 itemId, uint256 amount, address caller) external returns (bool);

    function setClaimRequirements(uint256 itemId, bytes calldata requirements) external;

    function setCraftRequirements(uint256 itemId, bytes calldata items) external;

    function checkClaimRequirements(address characterAccount, uint256 itemId, uint256 amount)
        external
        view
        returns (bool);

    function getClaimRequirements(uint256 itemId) external view returns (bytes memory);

    function getCraftRequirements(uint256 itemId) external view returns (bytes memory);
}
