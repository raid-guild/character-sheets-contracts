// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
pragma abicoder v2;

//solhint-disable

import "forge-std/Test.sol";
import "forge-std/console2.sol";

import "../src/implementations/ItemsImplementation.sol";
import {RequirementsTree, RequirementNode} from "../src/implementations/ItemsManagerImplementation.sol";
import "../src/lib/Structs.sol";
import "./setup/SetUp.sol";

contract ItemsTest is SetUp {
    event ItemDeleted(uint256 itemId);

    function testCreateClaimableItem() public {
        Item memory returnedItem = deployments.items.getItem(itemsData.itemIdClaimable);
        bytes memory itemRequirements = deployments.itemsManager.getClaimRequirements(itemsData.itemIdClaimable);
        RequirementNode memory node = RequirementsTree.decode(itemRequirements);
        string memory cid = deployments.items.uri(itemsData.itemIdClaimable);

        assertEq(itemsData.itemIdClaimable, 1, "incorrect item ID");
        assertEq(deployments.items.totalItemTypes(), 4, "incorrect number of items");
        assertEq(returnedItem.supply, 10 ** 18, "incorrect supply");
        assertEq(returnedItem.supplied, 0, "incorrect supplied amount");
        assertEq(node.operator, 0, "incorrect operator");
        assertEq(node.children.length, 0, "incorrect number of children");
        Asset memory asset = node.asset;
        assertEq(uint8(asset.category), uint8(Category.ERC20), "incorrect asset category");
        assertEq(asset.assetAddress, address(deployments.experience), "incorrect asset address");
        assertEq(asset.id, 0, "incorrect asset ID");
        assertEq(asset.amount, 100, "incorrect amount");
        assertEq(returnedItem.soulbound, true);
        assertEq(returnedItem.craftable, false);
        assertEq(returnedItem.claimable, bytes32(0));
        assertEq(cid, "test_base_uri_items/test_item_cid/", "incorrect CID");
    }

    function testCreateCraftableItem() public {
        Item memory returnedItem = deployments.items.getItem(itemsData.itemIdCraftable);
        bytes memory itemRequirements = deployments.itemsManager.getCraftRequirements(itemsData.itemIdCraftable);
        CraftItem[] memory craftRequirements = abi.decode(itemRequirements, (CraftItem[]));
        string memory cid = deployments.items.uri(itemsData.itemIdCraftable);

        assertEq(itemsData.itemIdCraftable, 2, "incorrect item ID");
        assertEq(deployments.items.totalItemTypes(), 4, "incorrect number of items");
        assertEq(returnedItem.supply, 10 ** 18, "incorrect supply");
        assertEq(returnedItem.supplied, 0, "incorrect supplied amount");
        assertEq(craftRequirements.length, 1, "incorrect number of craft requirements");
        assertEq(craftRequirements[0].amount, 1, "incorrect amount");
        assertEq(craftRequirements[0].itemId, itemsData.itemIdSoulbound, "incorrect item ID");
        assertEq(returnedItem.soulbound, false);
        assertEq(returnedItem.craftable, true);
        assertEq(returnedItem.claimable, bytes32(keccak256("null")));
        assertEq(cid, "test_base_uri_items/test_item_cid/", "incorrect CID");
    }

    function testDropLoot() public {
        dao.addMember(accounts.rando);

        vm.prank(accounts.rando);
        uint256 randoId = deployments.characterSheets.rollCharacterSheet("test_token_uri1/");

        vm.startPrank(accounts.gameMaster);

        address randoNPC = deployments.characterSheets.getCharacterSheetByCharacterId(randoId).accountAddress;

        uint256 _itemId =
            deployments.items.createItemType(createNewItem(false, false, bytes32(0), 1, createEmptyRequiredAssets()));
        assertEq(_itemId, 4, "incorrect itemId1");

        uint256 _itemId2 =
            deployments.items.createItemType(createNewItem(false, false, bytes32(0), 1, createEmptyRequiredAssets()));
        assertEq(_itemId2, 5, "incorrect itemId2");

        address[] memory players = new address[](2);
        players[0] = accounts.character1;
        players[1] = randoNPC;

        uint256[][] memory itemIds = new uint256[][](2);
        itemIds[0] = new uint256[](2);
        itemIds[0][0] = _itemId;
        itemIds[0][1] = _itemId2;

        itemIds[1] = new uint256[](2);
        itemIds[1][0] = _itemId;
        itemIds[1][1] = _itemId2;

        uint256[][] memory amounts = new uint256[][](2);
        amounts[0] = new uint256[](2);
        amounts[0][0] = 10000;
        amounts[0][1] = 1;
        amounts[1] = new uint256[](2);
        amounts[1][0] = 10001;
        amounts[1][1] = 2;

        deployments.experience.dropExp(accounts.character1, 100 * 10000);
        deployments.experience.dropExp(randoNPC, 100 * 10001);

        deployments.items.dropLoot(players, itemIds, amounts);
        vm.stopPrank();

        assertEq(deployments.items.balanceOf(accounts.character1, _itemId), 10000, "1: token id 0 not equal");
        assertEq(deployments.items.balanceOf(accounts.character1, _itemId2), 1, "1: token id 1 not equal");

        assertEq(deployments.items.balanceOf(randoNPC, _itemId), 10001, "2: token id 0 not equal");
        assertEq(deployments.items.balanceOf(randoNPC, _itemId2), 2, "2: token id 1 not equal");
    }

    function testClaimItem() public {
        vm.startPrank(accounts.gameMaster);
        uint256 _itemId1 = deployments.items.createItemType(
            createNewItem(
                false, true, bytes32(0), 1, createRequiredAsset(Category.ERC20, address(deployments.experience), 0, 100)
            )
        );
        uint256 _itemId2 = deployments.items.createItemType(
            createNewItem(
                false, true, bytes32(0), 1, createRequiredAsset(Category.ERC20, address(deployments.experience), 0, 100)
            )
        );

        // deployments.items.addItemRequirement(
        //     _itemId2, uint8(Category.ERC1155), address(deployments.classes), classData.classId, 1
        // );

        // need at least two leafs to create merkle tree
        uint256[] memory itemIds = new uint256[](2);
        itemIds[0] = _itemId1;
        itemIds[1] = _itemId2;
        address[] memory claimers = new address[](2);
        claimers[0] = accounts.character1;
        claimers[1] = accounts.player1;
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1;
        amounts[1] = 2;

        (bytes32[] memory proof, bytes32 root) = generateMerkleRootAndProof(itemIds, claimers, amounts, 0);

        deployments.items.updateItemClaimable(_itemId1, root, 1);

        uint256[] memory itemIds2 = new uint256[](1);
        bytes32[][] memory proofs = new bytes32[][](1);
        uint256[] memory amounts2 = new uint256[](1);
        itemIds2[0] = _itemId1;
        amounts2[0] = 1;
        proofs[0] = proof;
        vm.stopPrank();

        vm.prank(accounts.gameMaster);
        deployments.experience.dropExp(accounts.character1, 1000);

        vm.prank(accounts.gameMaster);
        deployments.classes.assignClass(accounts.character1, classData.classId);

        vm.prank(accounts.character1);
        deployments.items.claimItems(itemIds2, amounts2, proofs);

        assertEq(deployments.items.balanceOf(accounts.character1, _itemId1), 1, "Balance not equal");

        assertEq(deployments.experience.balanceOf(accounts.character1), 1000);
    }

    function testURI() public {
        string memory _uri = deployments.items.uri(0);
        assertEq(_uri, "test_base_uri_items/test_item_cid/", "incorrect uri returned");
    }

    function testDeleteItem() public {
        vm.startPrank(accounts.gameMaster);
        uint256 newItemId = deployments.items.createItemType(
            createNewItem(
                true, true, bytes32(0), 1, createRequiredAsset(Category.ERC20, address(deployments.experience), 0, 100)
            )
        );
        vm.expectEmit();
        emit ItemDeleted(newItemId);
        deployments.items.deleteItem(newItemId);
        vm.stopPrank();
        Item memory deleted = deployments.items.getItem(newItemId);

        assertEq(deleted.enabled, false, "item enabled");
    }

    function testCraftItem() public {
        vm.prank(accounts.gameMaster);
        uint256 _itemId =
            deployments.items.createItemType(createNewItem(false, false, bytes32(0), 1, createEmptyRequiredAssets()));
        assertEq(_itemId, 4, "incorrect itemId");

        vm.prank(accounts.gameMaster);
        uint256 craftableItemId = deployments.items.createItemType(
            createNewItem(
                true, true, bytes32(0), 1, createCraftingRequirement(_itemId, 100)
            )
        );

        address[] memory players = new address[](1);
        players[0] = accounts.character1;

        uint256[][] memory itemIds = new uint256[][](1);
        itemIds[0] = new uint256[](1);
        itemIds[0][0] = _itemId;

        uint256[][] memory amounts = new uint256[][](1);
        amounts[0] = new uint256[](1);
        amounts[0][0] = 100;

        vm.prank(accounts.gameMaster);
        deployments.items.dropLoot(players, itemIds, amounts);
        assertEq(deployments.items.balanceOf(accounts.character1, _itemId), 100, "item not dropped");

        // should succeed with requirements met
        vm.startPrank(accounts.character1);

        // must approve item manager to transfer items
        deployments.items.setApprovalForAll(address(deployments.itemsManager), true);

        deployments.items.craftItem(craftableItemId, 1);

        vm.stopPrank();

        assertEq(deployments.items.balanceOf(accounts.character1, craftableItemId), 1, "item not crafted");
        assertEq(deployments.items.balanceOf(accounts.character1, _itemId), 0, "item not consumed in crafting");
    }

    function testDismantleItems() public {

        vm.startPrank(accounts.gameMaster);

        uint256 _itemId1 =
            deployments.items.createItemType(createNewItem(false, false, bytes32(0), 1, createEmptyRequiredAssets()));
        assertEq(_itemId1, 4, "incorrect itemId");

        uint256 _itemId2 =
            deployments.items.createItemType(createNewItem(false, false, bytes32(0), 1, createEmptyRequiredAssets()));
        assertEq(_itemId2, 5, "incorrect itemId");

        address[] memory players = new address[](1);
        players[0] = accounts.character1;

        uint256[][] memory itemIds = new uint256[][](1);
        itemIds[0] = new uint256[](2);
        itemIds[0][0] = _itemId1;
        itemIds[0][1] = _itemId2;

        uint256[][] memory amounts = new uint256[][](1);
        amounts[0] = new uint256[](2);
        amounts[0][0] = 100;
        amounts[0][1] = 200;

        deployments.items.dropLoot(players, itemIds, amounts);
        assertEq(deployments.items.balanceOf(accounts.character1, _itemId1), 100, "item1 not dropped");
        assertEq(deployments.items.balanceOf(accounts.character1, _itemId2), 200, "item2 not dropped");

        bytes memory requiredAssets;
        {

            CraftItem[] memory requirements = new CraftItem[](2);
            requirements[0] = CraftItem(_itemId1, 50);
            requirements[1] = CraftItem(_itemId2, 100);

            requiredAssets = abi.encode(requirements);
        }

        uint256 craftableItemId =
            deployments.items.createItemType(createNewItem(true, true, bytes32(0), 1, requiredAssets));

        vm.stopPrank();

        // should succeed with requirements met
        vm.startPrank(accounts.character1);
        // approve the spending of required items
        deployments.items.setApprovalForAll(address(deployments.itemsManager), true);

        deployments.items.craftItem(craftableItemId, 2);

        assertEq(deployments.items.balanceOf(accounts.character1, _itemId1), 0, "item1 not consumed in crafting");
        assertEq(deployments.items.balanceOf(accounts.character1, _itemId2), 0, "item2 not consumed in crafting");

        // should revert if trying to dismantle un-crafted item
        vm.expectRevert(Errors.InsufficientBalance.selector);
        deployments.items.dismantleItems(0, 1);

        //should revert if trying to dismantle more than have been crafted
        vm.expectRevert(Errors.InsufficientBalance.selector);
        deployments.items.dismantleItems(craftableItemId, 4);

        //should succeed
        deployments.items.dismantleItems(craftableItemId, 1);

        assertEq(deployments.items.balanceOf(accounts.character1, craftableItemId), 1, "item not burnt");
        assertEq(deployments.items.balanceOf(accounts.character1, _itemId1), 50, "item1 not returned");
        assertEq(deployments.items.balanceOf(accounts.character1, _itemId2), 100, "item2 not returned");

        //should dismantle remaining items
        deployments.items.dismantleItems(craftableItemId, 1);

        assertEq(deployments.items.balanceOf(accounts.character1, craftableItemId), 0, "item 2 not burnt");
        assertEq(deployments.items.balanceOf(accounts.character1, _itemId1), 100, "item1 not returned");
        assertEq(deployments.items.balanceOf(accounts.character1, _itemId2), 200, "item2 not returned");
        vm.stopPrank();
    }

    // UNHAPPY PATH
    function testCreateItemTypeRevert() public {
        bytes memory newItem = createNewItem(false, false, bytes32(0), 1, createEmptyRequiredAssets());

        vm.startPrank(accounts.player2);
        vm.expectRevert(Errors.GameMasterOnly.selector);
        deployments.items.createItemType(newItem);
        vm.stopPrank();
    }

    function testDropLootRevert() public {
        vm.prank(accounts.gameMaster);
        uint256 _itemId = deployments.items.createItemType(
            createNewItem(false, false, bytes32(keccak256("null")), 0, createEmptyRequiredAssets())
        );
        assertEq(_itemId, 4);

        address[] memory players = new address[](1);
        players[0] = accounts.character1;
        uint256[][] memory itemIds = new uint256[][](2);
        itemIds[0] = new uint256[](2);
        itemIds[0][0] = 0;
        itemIds[0][1] = _itemId;
        itemIds[1] = new uint256[](2);
        itemIds[1][0] = 0;
        itemIds[1][1] = _itemId;

        uint256[][] memory amounts = new uint256[][](2);
        amounts[0] = new uint256[](2);
        amounts[0][0] = 10000;
        amounts[0][1] = 1;

        amounts[1] = new uint256[](2);
        amounts[1][0] = 1111;
        amounts[1][1] = 11;

        //revert wrong array lengths
        vm.prank(accounts.gameMaster);
        vm.expectRevert(Errors.LengthMismatch.selector);
        deployments.items.dropLoot(players, itemIds, amounts);

        //revert incorrect caller
        vm.prank(address(1));
        vm.expectRevert(Errors.GameMasterOnly.selector);
        deployments.items.dropLoot(players, itemIds, amounts);
    }

    function testCraftItemRevert() public {
        // should revert if item is not set to craftable
        vm.prank(accounts.character1);
        vm.expectRevert();
        deployments.items.craftItem(0, 1);

        vm.prank(accounts.gameMaster);
        uint256 craftableItemId = deployments.items.createItemType(
            createNewItem(
                true, true, bytes32(0), 1, createCraftingRequirement(3, 100)
            )
        );

        //should revert if requirements not met
        vm.prank(accounts.character1);
        vm.expectRevert(Errors.InsufficientBalance.selector);
        deployments.items.craftItem(craftableItemId, 1);
    }

    function testClaimItemRevert() public {
        vm.startPrank(accounts.gameMaster);
        uint256 _itemId1 = deployments.items.createItemType(
            createNewItem(
                false, true, bytes32(0), 1, createRequiredAsset(Category.ERC20, address(deployments.experience), 0, 100)
            )
        );
        uint256 _itemId2 = deployments.items.createItemType(
            createNewItem(
                false,
                true,
                bytes32(0),
                1,
                createRequiredAsset(Category.ERC1155, address(deployments.classes), classData.classId, 1)
            )
        );
        uint256 _itemId3 = deployments.items.createItemType(
            createNewItem(
                false, true, bytes32(0), 1, createRequiredAsset(Category.ERC20, address(deployments.experience), 0, 100)
            )
        );

        // need at least two leafs to create merkle tree
        uint256[] memory itemIds = new uint256[](2);
        itemIds[0] = _itemId1;
        itemIds[1] = _itemId2;
        address[] memory claimers = new address[](2);
        claimers[0] = accounts.character1;
        claimers[1] = accounts.player1;
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1;
        amounts[1] = 2;

        (bytes32[] memory proof, bytes32 root) = generateMerkleRootAndProof(itemIds, claimers, amounts, 0);

        deployments.items.updateItemClaimable(_itemId1, root, 1);

        uint256[] memory itemIds2 = new uint256[](1);
        bytes32[][] memory proofs = new bytes32[][](1);
        uint256[] memory amounts2 = new uint256[](1);
        itemIds2[0] = _itemId2;
        amounts2[0] = 1;
        proofs[0] = new bytes32[](2);
        vm.stopPrank();

        // revert with not enough req items
        vm.prank(accounts.character1);
        vm.expectRevert(Errors.RequirementNotMet.selector);
        deployments.items.claimItems(itemIds2, amounts2, proofs);

        vm.prank(accounts.gameMaster);
        deployments.experience.dropExp(accounts.character1, 1000);

        // revert wrong class
        vm.prank(accounts.character1);
        vm.expectRevert(Errors.RequirementNotMet.selector);
        deployments.items.claimItems(itemIds2, amounts2, proofs);

        vm.prank(accounts.gameMaster);
        deployments.classes.assignClass(accounts.character1, classData.classId);

        itemIds2[0] = _itemId1;
        //revert invalid proof
        vm.prank(accounts.character1);
        vm.expectRevert(Errors.InvalidProof.selector);
        deployments.items.claimItems(itemIds2, amounts2, proofs);

        proofs[0] = proof;

        vm.prank(accounts.character1);
        deployments.items.claimItems(itemIds2, amounts2, proofs);

        //revert on second attempt to claim
        vm.prank(accounts.character1);
        vm.expectRevert(abi.encodeWithSelector(Errors.CannotClaim.selector, 1));
        deployments.items.claimItems(itemIds2, amounts2, proofs);

        itemIds2[0] = _itemId3;
        amounts2[0] = 5;
        //revert if trying to claim more than allowed amount
        vm.prank(accounts.character1);
        vm.expectRevert(abi.encodeWithSelector(Errors.CannotClaim.selector, 1));
        deployments.items.claimItems(itemIds2, amounts2, proofs);
    }
}
