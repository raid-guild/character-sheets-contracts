// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
pragma abicoder v2;

//solhint-disable

import "forge-std/Test.sol";
import "../src/implementations/ExperienceAndItemsImplementation.sol";
import "./helpers/SetUp.sol";
import "../src/lib/Structs.sol";

contract ExperienceAndItemsTest is Test, SetUp {
    function testCreateItemType() public {
        bytes memory newItem = createNewItem("Pirate_Hat", false, bytes32(0));
        vm.prank(admin);
        uint256 _itemId = experience.createItemType(newItem);

        Item memory returnedItem = experience.getItemById(_itemId);

        assertEq(experience.totalItemTypes(), 2);
        assertEq(keccak256(abi.encode(returnedItem.name)), keccak256(abi.encode("Pirate_Hat")));
        assertEq(returnedItem.tokenId, 2);
        assertEq(returnedItem.supply, 10 ** 18);
        assertEq(returnedItem.supplied, 0);
        assertEq(returnedItem.itemRequirements.length, 1);
        assertEq(returnedItem.soulbound, false);
        assertEq(returnedItem.claimable, bytes32(0));
        assertEq(keccak256(abi.encode(returnedItem.cid)), keccak256(abi.encode("test_item_cid/")));
        assertEq(
            keccak256(abi.encode(experience.uri(returnedItem.tokenId))),
            keccak256(abi.encode("test_base_uri_experience/test_item_cid/")),
            "uris not right"
        );
    }

    function testBatchCreateItemType() public {
        bytes[] memory _items = new bytes[](2);
        _items[0] = createNewItem("Pirate_Hat1", false, bytes32(0));
        _items[1] = createNewItem("Pirate_Hat2", false, bytes32(0));
        vm.prank(admin);
        uint256[] memory _itemIds = experience.batchCreateItemType(_items);

        assertEq(_itemIds.length, 2);

        uint256 _itemId = _itemIds[0];

        Item memory returnedItem = experience.getItemById(_itemId);

        assertEq(experience.totalItemTypes(), 3);
        assertEq(keccak256(abi.encode(returnedItem.name)), keccak256(abi.encode("Pirate_Hat1")));
        assertEq(_itemId, 2);
        assertEq(returnedItem.tokenId, 2);
        assertEq(returnedItem.supply, 10 ** 18);
        assertEq(returnedItem.supplied, 0);
        assertEq(returnedItem.itemRequirements.length, 1);
        assertEq(returnedItem.soulbound, false);
        assertEq(returnedItem.claimable, bytes32(0));
        assertEq(keccak256(abi.encode(returnedItem.cid)), keccak256(abi.encode("test_item_cid/")));
        assertEq(
            keccak256(abi.encode(experience.uri(returnedItem.tokenId))),
            keccak256(abi.encode("test_base_uri_experience/test_item_cid/")),
            "uris not right"
        );

        _itemId = _itemIds[1];

        returnedItem = experience.getItemById(_itemId);

        assertEq(experience.totalItemTypes(), 3);
        assertEq(keccak256(abi.encode(returnedItem.name)), keccak256(abi.encode("Pirate_Hat2")));
        assertEq(_itemId, 3);
        assertEq(returnedItem.tokenId, 3);
        assertEq(returnedItem.supply, 10 ** 18);
        assertEq(returnedItem.supplied, 0);
        assertEq(returnedItem.itemRequirements.length, 1);
        assertEq(returnedItem.soulbound, false);
        assertEq(returnedItem.claimable, bytes32(0));
        assertEq(keccak256(abi.encode(returnedItem.cid)), keccak256(abi.encode("test_item_cid/")));
        assertEq(
            keccak256(abi.encode(experience.uri(returnedItem.tokenId))),
            keccak256(abi.encode("test_base_uri_experience/test_item_cid/")),
            "uris not right"
        );
    }

    function testCreateItemTypeRevertItemExists() public {
        bytes memory newItem = createNewItem("Pirate_Hat", false, bytes32(0));

        vm.startPrank(admin);
        experience.createItemType(newItem);

        vm.expectRevert();
        experience.createItemType(newItem);

        vm.stopPrank();
    }

    function testCreateItemTypeRevertAccessControl() public {
        bytes memory newItem = createNewItem("Pirate_Hat", false, bytes32(0));

        vm.startPrank(player2);
        vm.expectRevert();
        experience.createItemType(newItem);
        vm.stopPrank();
    }

    function testDropLoot() public {
        dao.addMember(player2);
        vm.prank(player2);
        uint256 player2Id = characterSheets.rollCharacterSheet(player2, abi.encode("player 2", "test_token_uri1/"));
        vm.startPrank(admin);

        bytes memory newItem = createNewItem("staff", false, bytes32(0));

        address player2NPC = characterSheets.getCharacterSheetByCharacterId(player2Id).ERC6551TokenAddress;
        uint256 _itemId = experience.createItemType(newItem);

        address[] memory players = new address[](2);
        players[0] = npc1;
        players[1] = player2NPC;

        uint256[][] memory itemIds = new uint256[][](2);
        itemIds[0] = new uint256[](3);
        itemIds[0][0] = 0;
        itemIds[0][1] = 1;
        itemIds[0][2] = _itemId;

        itemIds[1] = new uint256[](3);
        itemIds[1][0] = 0;
        itemIds[1][1] = 1;
        itemIds[1][2] = _itemId;

        uint256[][] memory amounts = new uint256[][](2);
        amounts[0] = new uint256[](3);
        amounts[0][0] = 10000;
        amounts[0][1] = 1;
        amounts[0][2] = 1;
        amounts[1] = new uint256[](3);
        amounts[1][0] = 10001;
        amounts[1][1] = 2;
        amounts[1][2] = 2;

        experience.dropLoot(players, itemIds, amounts);
        vm.stopPrank();

        assertEq(experience.balanceOf(npc1, 0), 10000, "exp not equal");
        assertEq(experience.balanceOf(npc1, 1), 1, "token id 1 not equal");

        assertEq(experience.balanceOf(player2NPC, 0), 10001, "2: exp not equal");
        assertEq(experience.balanceOf(player2NPC, 1), 2, "2: token id 1 not equal");
    }

    function testDropLootRevert() public {
        vm.prank(admin);
        uint256 _itemId = createNewItemType("staff");
        address[] memory players = new address[](1);
        players[0] = npc1;
        uint256[][] memory itemIds = new uint256[][](2);
        itemIds[0] = new uint256[](3);
        itemIds[0][0] = 0;
        itemIds[0][1] = 1;
        itemIds[0][2] = _itemId;
        itemIds[1] = new uint256[](3);
        itemIds[1][0] = 0;
        itemIds[1][1] = 1;
        itemIds[1][2] = _itemId;

        uint256[][] memory amounts = new uint256[][](2);
        amounts[0] = new uint256[](3);
        amounts[0][0] = 10000;
        amounts[0][1] = 1;
        amounts[0][2] = 1;

        amounts[1] = new uint256[](3);
        amounts[1][0] = 1111;
        amounts[1][1] = 11;
        amounts[1][2] = 11;

        //revert incorrect caller
        vm.prank(player1);
        vm.expectRevert();
        experience.dropLoot(players, itemIds, amounts);
        //revert wrong array lengths
        vm.prank(admin);
        vm.expectRevert();
        experience.dropLoot(players, itemIds, amounts);
    }

    function testClaimItem() public {
        vm.startPrank(admin);
        uint256 _itemId = createNewItemType("WANG!");

        experience.addClassRequirement(_itemId, testClassId);
        uint256[] memory itemIds = new uint256[](2);
        itemIds[0] = _itemId;
        itemIds[1] = 4;
        address[] memory claimers = new address[](2);
        claimers[0] = npc1;
        claimers[1] = player2;
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1;
        amounts[1] = 100;

        (bytes32[] memory proof, bytes32 root) = generateMerkleRootAndProof(itemIds, claimers, amounts, 0);

        experience.updateItemClaimable(_itemId, root);

        uint256[] memory itemIds2 = new uint256[](1);
        bytes32[][] memory proofs = new bytes32[][](1);
        uint256[] memory amounts2 = new uint256[](1);
        itemIds2[0] = _itemId;
        amounts2[0] = 1;
        proofs[0] = new bytes32[](2);
        vm.stopPrank();
        // revert with not enough req exp
        vm.prank(npc1);
        vm.expectRevert();
        experience.claimItems(itemIds2, amounts2, proofs);

        dropExp(npc1, 1000);
        // revert wrong class
        vm.prank(npc1);
        vm.expectRevert();
        experience.claimItems(itemIds2, amounts2, proofs);

        vm.prank(admin);
        classes.assignClass(1, testClassId);

        //revert invalid proof
        vm.prank(npc1);
        vm.expectRevert();
        experience.claimItems(itemIds2, amounts2, proofs);

        proofs[0] = proof;

        vm.prank(npc1);
        experience.claimItems(itemIds2, amounts2, proofs);

        assertEq(experience.balanceOf(npc1, _itemId), 1, "Balance not equal");

        assertEq(experience.balanceOf(npc1, 0), 900);
    }

    function testFindItemByName() public {
        uint256 itemId = experience.findItemByName("test_item");
        assertEq(itemId, 1);
        vm.expectRevert();
        experience.findItemByName("no_Item");
    }

    function testURI() public {
        string memory _uri = experience.uri(1);
        assertEq(
            keccak256(abi.encode(_uri)),
            keccak256(abi.encode("test_base_uri_experience/test_item_cid/")),
            "incorrect uri returned"
        );
    }

    function testAddItemRequirement() public {
        vm.prank(admin);
        uint256 tokenId = createNewItemType("hat");

        vm.prank(admin);
        experience.addItemRequirement(1, tokenId, 100);

        Item memory modifiedItem = experience.getItemById(1);

        assertEq(modifiedItem.itemRequirements.length, 2, "Requirement not added");
        assertEq(experience.getItemById(1).itemRequirements[1][0], tokenId, "wrong Id in itemRequirements array");
    }

    function testRemoveItemRequirement() public {
        vm.prank(admin);
        uint256 tokenId = createNewItemType("hat");

        vm.prank(admin);
        experience.addItemRequirement(1, tokenId, 100);

        Item memory modifiedItem = experience.getItemById(1);

        assertEq(modifiedItem.itemRequirements.length, 2, "Requirement not added");
        assertEq(experience.getItemById(1).itemRequirements[1][0], tokenId, "wrong Id in itemRequirements array");

        vm.prank(admin);
        experience.removeItemRequirement(1, tokenId);

        modifiedItem = experience.getItemById(1);
        assertEq(modifiedItem.itemRequirements.length, 1, "requirement not removed");
        assertEq(modifiedItem.itemRequirements[0][0], 0, "wrong requirement removed");
        assertEq(modifiedItem.itemRequirements[0][1], 100, "Incorrect remaining amount");
    }
}
