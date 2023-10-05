// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
pragma abicoder v2;

//solhint-disable

import "forge-std/Test.sol";

import "../src/implementations/ItemsImplementation.sol";
import "../src/lib/Structs.sol";
import "./helpers/SetUp.sol";

contract ItemsTest is Test, SetUp {
    function testCreateItemTypeWithoutRequirements() public {
        bytes memory newItem = createNewItemWithoutRequirements(false, false, bytes32(0));
        vm.prank(admin);
        uint256 _itemId = items.createItemType(newItem);

        Item memory returnedItem = items.getItem(_itemId);
        Asset[] memory itemRequirements = items.getItemRequirements(_itemId);
        string memory cid = items.uri(_itemId);

        assertEq(_itemId, 1);
        assertEq(items.totalItemTypes(), 2);
        assertEq(returnedItem.supply, 10 ** 18);
        assertEq(returnedItem.supplied, 0);
        assertEq(itemRequirements.length, 0);
        assertEq(returnedItem.soulbound, false);
        assertEq(returnedItem.claimable, bytes32(0));
        assertEq(cid, "test_base_uri_items/test_item_cid/", "incorrect CID");
    }

    function testCreateItemType() public {
        bytes memory newItem = createNewItem(false, false, bytes32(0));
        vm.prank(admin);
        uint256 _itemId = items.createItemType(newItem);

        Item memory returnedItem = items.getItem(_itemId);
        Asset[] memory itemRequirements = items.getItemRequirements(_itemId);
        string memory cid = items.uri(_itemId);

        assertEq(_itemId, 1);
        assertEq(items.totalItemTypes(), 2);
        assertEq(returnedItem.supply, 10 ** 18);
        assertEq(returnedItem.supplied, 0);
        assertEq(itemRequirements.length, 1);
        assertEq(returnedItem.soulbound, false);
        assertEq(returnedItem.claimable, bytes32(0));
        assertEq(cid, "test_base_uri_items/test_item_cid/", "incorrect CID");
    }

    function testCreateItemTypeRevertAccessControl() public {
        bytes memory newItem = createNewItem(false, false, bytes32(0));

        vm.startPrank(player2);
        vm.expectRevert();
        items.createItemType(newItem);
        vm.stopPrank();
    }

    function testDropLoot() public {
        dao.addMember(player2);

        vm.prank(player2);
        uint256 player2Id = characterSheets.rollCharacterSheet("test_token_uri1/");

        vm.startPrank(admin);

        address player2NPC = characterSheets.getCharacterSheetByCharacterId(player2Id).accountAddress;

        uint256 _itemId = createNewItemType();
        assertEq(_itemId, 1);

        uint256 _itemId2 = createNewItemType();
        assertEq(_itemId2, 2);

        address[] memory players = new address[](2);
        players[0] = npc1;
        players[1] = player2NPC;

        uint256[][] memory itemIds = new uint256[][](2);
        itemIds[0] = new uint256[](2);
        itemIds[0][0] = 1;
        itemIds[0][1] = 2;

        itemIds[1] = new uint256[](2);
        itemIds[1][0] = 1;
        itemIds[1][1] = 2;

        uint256[][] memory amounts = new uint256[][](2);
        amounts[0] = new uint256[](2);
        amounts[0][0] = 10000;
        amounts[0][1] = 1;
        amounts[1] = new uint256[](2);
        amounts[1][0] = 10001;
        amounts[1][1] = 2;

        experience.dropExp(npc1, 100 * 10000);
        experience.dropExp(player2NPC, 100 * 10001);

        items.dropLoot(players, itemIds, amounts);
        vm.stopPrank();

        assertEq(items.balanceOf(npc1, 1), 10000, "1: token id 0 not equal");
        assertEq(items.balanceOf(npc1, 2), 1, "1: token id 1 not equal");

        assertEq(items.balanceOf(player2NPC, 1), 10001, "2: token id 0 not equal");
        assertEq(items.balanceOf(player2NPC, 2), 2, "2: token id 1 not equal");
    }

    function testDropLootRevert() public {
        vm.prank(admin);
        uint256 _itemId = createNewItemType();
        assertEq(_itemId, 1);

        address[] memory players = new address[](1);
        players[0] = npc1;
        uint256[][] memory itemIds = new uint256[][](2);
        itemIds[0] = new uint256[](2);
        itemIds[0][0] = 0;
        itemIds[0][1] = 1;
        itemIds[1] = new uint256[](2);
        itemIds[1][0] = 0;
        itemIds[1][1] = 1;

        uint256[][] memory amounts = new uint256[][](2);
        amounts[0] = new uint256[](2);
        amounts[0][0] = 10000;
        amounts[0][1] = 1;

        amounts[1] = new uint256[](2);
        amounts[1][0] = 1111;
        amounts[1][1] = 11;

        //revert incorrect caller
        vm.prank(player1);
        vm.expectRevert();
        items.dropLoot(players, itemIds, amounts);
        //revert wrong array lengths
        vm.prank(admin);
        vm.expectRevert();
        items.dropLoot(players, itemIds, amounts);
    }

    function testClaimItem() public {
        vm.startPrank(admin);
        uint256 _itemId1 = createNewItemType();
        uint256 _itemId2 = createNewItemType();

        items.addItemRequirement(_itemId1, uint8(Category.ERC1155), address(classes), testClassId, 1);

        // need atleast two leafs to create merkle tree
        uint256[] memory itemIds = new uint256[](2);
        itemIds[0] = _itemId1;
        itemIds[1] = _itemId2;
        address[] memory claimers = new address[](2);
        claimers[0] = npc1;
        claimers[1] = player1;
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1;
        amounts[1] = 2;

        (bytes32[] memory proof, bytes32 root) = generateMerkleRootAndProof(itemIds, claimers, amounts, 0);

        items.updateItemClaimable(_itemId1, root);

        uint256[] memory itemIds2 = new uint256[](1);
        bytes32[][] memory proofs = new bytes32[][](1);
        uint256[] memory amounts2 = new uint256[](1);
        itemIds2[0] = _itemId1;
        amounts2[0] = 1;
        proofs[0] = new bytes32[](2);
        vm.stopPrank();

        // revert with not enough req items
        vm.prank(npc1);
        vm.expectRevert();
        items.claimItems(itemIds2, amounts2, proofs);

        vm.prank(admin);
        experience.dropExp(npc1, 1000);

        // revert wrong class
        vm.prank(npc1);
        vm.expectRevert();
        items.claimItems(itemIds2, amounts2, proofs);

        vm.prank(admin);
        classes.assignClass(npc1, testClassId);

        //revert invalid proof
        vm.prank(npc1);
        vm.expectRevert();
        items.claimItems(itemIds2, amounts2, proofs);

        proofs[0] = proof;

        vm.prank(npc1);
        items.claimItems(itemIds2, amounts2, proofs);

        assertEq(items.balanceOf(npc1, _itemId1), 1, "Balance not equal");

        assertEq(experience.balanceOf(npc1), 1000);
    }

    function testURI() public {
        string memory _uri = items.uri(0);
        assertEq(_uri, "test_base_uri_items/test_item_cid/", "incorrect uri returned");
    }

    function testAddItemRequirement() public {
        vm.prank(admin);
        uint256 tokenId = createNewItemType();

        vm.prank(admin);
        items.addItemRequirement(0, uint8(Category.ERC1155), address(items), tokenId, 100);

        Asset[] memory requiredAssets = items.getItemRequirements(0);

        assertEq(requiredAssets.length, 2, "Requirement not added");

        Asset memory requiredAsset = requiredAssets[1];
        assertEq(requiredAsset.id, tokenId, "wrong Id in itemRequirements array");
        assertEq(requiredAsset.amount, 100, "wrong amount in itemRequirements array");
        assertEq(uint256(requiredAsset.category), uint256(Category.ERC1155), "wrong category in itemRequirements array");
        assertEq(requiredAsset.assetAddress, address(items), "wrong address in itemRequirements array");
    }

    function testRemoveItemRequirement() public {
        vm.prank(admin);
        uint256 tokenId = createNewItemType();

        vm.prank(admin);
        items.addItemRequirement(0, uint8(Category.ERC1155), address(items), tokenId, 1000);

        Asset[] memory requiredAssets = items.getItemRequirements(0);

        assertEq(requiredAssets.length, 2, "Requirement not added");

        Asset memory requiredAsset = requiredAssets[1];
        assertEq(requiredAsset.id, tokenId, "wrong Id in itemRequirements array");
        assertEq(requiredAsset.amount, 1000, "wrong amount in itemRequirements array");
        assertEq(uint256(requiredAsset.category), uint256(Category.ERC1155), "wrong category in itemRequirements array");
        assertEq(requiredAsset.assetAddress, address(items), "wrong address in itemRequirements array");

        vm.prank(admin);
        items.removeItemRequirement(0, address(items), tokenId);

        requiredAssets = items.getItemRequirements(0);
        assertEq(requiredAssets.length, 1, "requirement not removed");

        requiredAsset = requiredAssets[0];
        assertEq(requiredAsset.id, 0, "wrong Id in itemRequirements array");
        assertEq(requiredAsset.amount, 100, "wrong amount in itemRequirements array");
        assertEq(uint256(requiredAsset.category), uint256(Category.ERC20), "wrong category in itemRequirements array");
        assertEq(requiredAsset.assetAddress, address(experience), "wrong address in itemRequirements array");
    }

    function testCraftItem() public {
        // should revert if item is not set to craftable
        vm.prank(npc1);
        vm.expectRevert();
        items.craftItem(0, 1);
    }
}
