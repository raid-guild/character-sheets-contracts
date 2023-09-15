// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
pragma abicoder v2;

interface IItems {
    function batchCreateItemType(bytes[] calldata itemDatas) external returns (uint256[] memory tokenIds);

    function dropLoot(address[] calldata nftAddress, uint256[][] calldata itemIds, uint256[][] calldata amounts)
        external
        returns (bool success);

    function claimItems(uint256[] calldata itemIds, uint256[] calldata amounts, bytes32[][] calldata proofs)
        external
        returns (bool success);

    function craftItem(uint256 itemId, uint256 amount) external returns (bool);

    function createItemType(bytes calldata itemData) external returns (uint256 tokenId);

    function addItemRequirement(uint256 itemId, uint256 requiredItemId, uint256 amount)
        external
        returns (bool success);

    function addClassRequirement(uint256 itemId, uint256 requiredClassId) external returns (bool success);

    function removeItemRequirement(uint256 itemId, uint256 removedItemId) external returns (bool);

    function removeClassRequirement(uint256 itemId, uint256 removedClassId) external returns (bool);
}
