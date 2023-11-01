// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Item, Asset} from "../lib/Structs.sol";

interface IItems {
    function dropLoot(address[] calldata characterAccounts, uint256[][] calldata itemIds, uint256[][] calldata amounts)
        external
        returns (bool success);

    function claimItems(uint256[] calldata itemIds, uint256[] calldata amounts, bytes32[][] calldata proofs)
        external
        returns (bool success);

    function dismantleItems(uint256 itemId, uint256 amount) external returns (bool success);

    function updateItemClaimable(uint256 itemId, bytes32 merkleRoot, uint256 newDistribution) external;

    function craftItem(uint256 itemId, uint256 amount) external returns (bool);

    function setURI(uint256 tokenId, string memory tokenURI) external;

    function createItemType(bytes calldata itemData) external returns (uint256 tokenId);

    function deleteItem(uint256 itemId) external;

    function setBaseURI(string memory _baseUri) external;

    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes memory data) external;

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) external;

    function withdrawAsset(Asset calldata asset, address to) external;

    function supportsInterface(bytes4 interfaceId) external returns (bool);

    function getClaimNonce(uint256 itemId, address character) external view returns (uint256);

    function getBaseURI() external view returns (string memory);

    function uri(uint256 _itemId) external view returns (string memory);

    function getItem(uint256 itemId) external view returns (Item memory);

    function balanceOf(address account, uint256 itemId) external view returns (uint256);
}
