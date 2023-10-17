// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Item} from "../lib/Structs.sol";

interface IItems {
    function dropLoot(address[] calldata characterAccounts, uint256[][] calldata itemIds, uint256[][] calldata amounts)
        external
        returns (bool success);

    function claimItems(uint256[] calldata itemIds, uint256[] calldata amounts, bytes32[][] calldata proofs)
        external
        returns (bool success);

    function craftItem(uint256 itemId, uint256 amount) external returns (bool);

    function createItemType(bytes calldata itemData) external returns (uint256 tokenId);

    function addItemRequirement(uint256 itemId, uint8 category, address assetAddress, uint256 assetId, uint256 amount)
        external
        returns (bool);

    function removeItemRequirement(uint256 itemId, address assetAddress, uint256 assetId) external returns (bool);

    function getItem(uint256 itemId) external view returns (Item memory);
}
