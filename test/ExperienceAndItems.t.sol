// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;
pragma abicoder v2;

import 'forge-std/Test.sol';
import '../src/implementations/ExperienceAndItemsImplementation.sol';
import './helpers/SetUp.sol';
import '../src/lib/Structs.sol';

contract ExperienceAndItemsTest is Test, SetUp {
    function testCreateClass() public {
        vm.prank(admin);
        (uint256 _tokenId, uint256 _classId) = experience.createClassType(createNewClass('Ballerina'));
        (uint256 tokenId, uint256 classId, string memory name, uint256 supply, string memory cid) =
            experience.classes(_classId);

        assertEq(experience.totalClasses(), 2);
        assertEq(tokenId, 3);
        assertEq(_tokenId, 3);
        assertEq(_classId, 2);
        assertEq(classId, 2);
        assertEq(keccak256(abi.encode(name)), keccak256(abi.encode('Ballerina')));
        assertEq(supply, 0);
        assertEq(keccak256(abi.encode(cid)), keccak256(abi.encode('test_class_cid/')));
        assertEq(
            keccak256(abi.encode(experience.uri(tokenId))),
            keccak256(abi.encode('test_base_uri_experience/test_class_cid/')),
            'incorrect token uri'
        );
    }

    function testAssignClass() public {
        uint256 playerId = characterSheets.memberAddressToTokenId(player1);
        vm.startPrank(admin);

        (uint256 tokenId, uint256 classId) = experience.createClassType(createNewClass('Ballerina'));

        experience.assignClass(playerId, classId);
        vm.stopPrank();

        CharacterSheet memory player = characterSheets.getCharacterSheetByCharacterId(playerId);

        assertEq(experience.balanceOf(npc1, tokenId), 1);

        //add second class
        vm.prank(admin);
        experience.assignClass(playerId, 1);

        CharacterSheet memory secondPlayer = characterSheets.getCharacterSheetByCharacterId(playerId);

        assertEq(experience.balanceOf(secondPlayer.ERC6551TokenAddress, 2), 1, 'does not own second class');
    }

    function testAssignClasses() public {
        uint256 playerId = characterSheets.memberAddressToTokenId(player1);
        vm.startPrank(admin);

        (uint256 tokenId, uint256 classId) = experience.createClassType(createNewClass('Ballerina'));
        Class[] memory allClasses = experience.getAllClasses();

        uint256[] memory classes = new uint256[](2);
        classes[0] = allClasses[0].classId;
        classes[1] = allClasses[1].classId;
        experience.assignClasses(playerId, classes);
        vm.stopPrank();
        CharacterSheet memory player = characterSheets.getCharacterSheetByCharacterId(playerId);
        assertEq(experience.balanceOf(player.ERC6551TokenAddress, allClasses[0].tokenId), 1, 'incorrect balance');
        assertEq(experience.balanceOf(player.ERC6551TokenAddress, allClasses[1].tokenId), 1, 'incorrect balance token 2');
    }

    function testRevokeClass() public {
        uint256 playerId = characterSheets.memberAddressToTokenId(player1);

        vm.startPrank(admin);
        (uint256 tokenId,) = experience.createClassType(createNewClass('Ballerina'));

        Class[] memory allClasses = experience.getAllClasses();

        uint256[] memory classes = new uint256[](2);
        classes[0] = allClasses[0].classId;
        classes[1] = allClasses[1].classId;

        experience.assignClasses(playerId, classes);
        vm.stopPrank();

        vm.prank(player1);
        experience.revokeClass(playerId, allClasses[0].classId);

        CharacterSheet memory sheet = characterSheets.getCharacterSheetByCharacterId(playerId);

        assertEq(experience.balanceOf(sheet.ERC6551TokenAddress, tokenId), 1, 'Incorrect class balance');

    }

    function testCreateItemType() public {
        bytes memory newItem = createNewItem('Pirate_Hat', false, bytes32(0));
        vm.prank(admin);
        (uint256 _tokenId, uint256 _itemId) = experience.createItemType(newItem);

        Item memory returnedItem = experience.getItemById(_itemId);


        assertEq(experience.totalItemTypes(), 2);
        assertEq(keccak256(abi.encode(returnedItem.name)), keccak256(abi.encode('Pirate_Hat')));
        assertEq(returnedItem.tokenId, _tokenId);
        assertEq(returnedItem.tokenId, 3);
        assertEq(returnedItem.supply, 10 ** 18);
        assertEq(returnedItem.supplied, 0);
        assertEq(returnedItem.requirements.length, 1);
        assertEq(returnedItem.soulbound, false);
        assertEq(returnedItem.claimable, bytes32(0));
        assertEq(keccak256(abi.encode(returnedItem.cid)), keccak256(abi.encode('test_item_cid/')));
        assertEq(
            keccak256(abi.encode(experience.uri(returnedItem.tokenId))),
            keccak256(abi.encode('test_base_uri_experience/test_item_cid/')),
            'uris not right'
        );
        assertEq(returnedItem.itemId, _itemId, 'wrong item ids');
    }

    function testCreateItemTypeRevertItemExists() public {
        bytes memory newItem = createNewItem('Pirate_Hat', false, bytes32(0));

        vm.startPrank(admin);
        experience.createItemType(newItem);

        vm.expectRevert('Item already exists.');
        experience.createItemType(newItem);

        vm.stopPrank();
    }

    function testCreateItemTypeRevertAccessControl() public {
        bytes memory newItem = createNewItem('Pirate_Hat', false, bytes32(0));

        vm.startPrank(player2);
        vm.expectRevert('You must be the Dungeon Master');
        experience.createItemType(newItem);
        vm.stopPrank();
    }

    function testDropLoot() public {
        vm.startPrank(admin);
        bytes memory newItem = createNewItem('staff', false, bytes32(0));

        dao.addMember(player2);

        uint256 player2Id = characterSheets.rollCharacterSheet(player2, abi.encode('player 2', 'test_token_uri1/'));
        address player2NPC = characterSheets.getCharacterSheetByCharacterId(player2Id).ERC6551TokenAddress;
        (uint256 _tokenId, uint256 _itemId) = experience.createItemType(newItem);

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

        assertEq(experience.balanceOf(npc1, _tokenId), 1, 'tokenId 3 not equal');
        assertEq(experience.balanceOf(npc1, 0), 10000, 'exp not equal');
        assertEq(experience.balanceOf(npc1, 1), 1, 'token id 1 not equal');

        assertEq(experience.balanceOf(player2NPC, _tokenId), 2, '2: tokenId 3 not equal');
        assertEq(experience.balanceOf(player2NPC, 0), 10001, '2: exp not equal');
        assertEq(experience.balanceOf(player2NPC, 1), 2, '2: token id 1 not equal');

    }

    function testDropLootRevert() public {
        vm.prank(admin);
        (, uint256 _itemId) = createNewItemType('staff');
        address[] memory players = new address[](1);
        players[0] = npc1;
        uint256[][] memory itemIds =new uint256[][](2);
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


        vm.prank(player1);
        vm.expectRevert('You must be the Dungeon Master');
        experience.dropLoot(players, itemIds, amounts);

        vm.prank(admin);
        vm.expectRevert('LENGTH MISMATCH');
        experience.dropLoot(players, itemIds, amounts);
    }

    function testClaimItem() public {
        vm.startPrank(admin);
        (uint256 _tokenId, uint256 _itemId) = createNewItemType('staff');
        
        experience.addItemOrClassRequirement(_itemId, testClassTokenId, 1);
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
        proofs[0] = proof;
        vm.stopPrank();
        
        vm.prank(npc1);
        vm.expectRevert('Not enough required item.');
        experience.claimItems(itemIds2, amounts2, proofs);

        dropExp(npc1, 1000);

        vm.prank(npc1);
        vm.expectRevert('Character does not have this class');
        experience.claimItems(itemIds2, amounts2, proofs);
        
        vm.prank(admin);
        experience.assignClass(1, testClassId);

        vm.prank(npc1);
        experience.claimItems(itemIds2, amounts2, proofs);

        
        assertEq(experience.balanceOf(npc1, _tokenId), 1, 'Balance not equal');

        assertEq(experience.balanceOf(npc1, 0), 900);
    }

    function testClaimItemWithClassRequirement() public {

    }

    function testFindItemByName() public {
        (uint256 tokenId, uint256 itemId) = experience.findItemByName('test_item');
        assertEq(itemId, 1);
        assertEq(tokenId, 1);

        vm.expectRevert('No item found.');
        experience.findItemByName('no_Item');
    }

    function testFindClassByName() public {
        (uint256 tokenId, uint256 classId) = experience.findClassByName('test_class');
        assertEq(classId, 1);
        assertEq(tokenId, 2);

        vm.expectRevert('No class found.');
        experience.findClassByName('no_class');
    }

    function testFindItemIdOrClassFromTokenId() public {
        (uint256 itemId,) = experience.findItemOrClassIdFromTokenId(1);

        assertEq(itemId, 1, 'incorrect itemId');

        //test that it revert;
        vm.expectRevert('this tokenId is not an item or a class');
        experience.findItemOrClassIdFromTokenId(250);

        //should return 0, false for exp;

        (uint256 itemOrClassId, bool isClass) = experience.findItemOrClassIdFromTokenId(0);
        assertEq(itemOrClassId, 0, 'exp id wrong');
        assertEq(isClass, false, 'isClass wrong');

        (uint256 itemId2, bool isAlsoClass ) = experience.findItemOrClassIdFromTokenId(2);

        assertEq(itemId2, 1, 'Wrong Class Id');
        assertEq(isAlsoClass, true, 'Wrong class bool');

    }

    function testURI() public {
        string memory _uri = experience.uri(1);
        assertEq(
            keccak256(abi.encode(_uri)),
            keccak256(abi.encode('test_base_uri_experience/test_item_cid/')),
            'incorrect uri returned'
        );
    }

    function testAddItemOrClassRequirement() public {
        vm.prank(admin);
        (uint256 tokenId,) = createNewItemType('hat');

        vm.prank(admin);
        experience.addItemOrClassRequirement(1, tokenId, 100);

        Item memory modifiedItem = experience.getItemById(1);

        assertEq(modifiedItem.requirements.length, 2, 'Requirement not added');
        assertEq(experience.getItemById(1).requirements[1][0], tokenId, 'wrong Id in requirements array');
    }

    function testRemoveItemRequirement() public {
        vm.prank(admin);
        (uint256 tokenId,) = createNewItemType('hat');

        vm.prank(admin);
        experience.addItemOrClassRequirement(1, tokenId, 100);

        Item memory modifiedItem = experience.getItemById(1);

        assertEq(modifiedItem.requirements.length, 2, 'Requirement not added');
        assertEq(experience.getItemById(1).requirements[1][0], tokenId, 'wrong Id in requirements array');

        vm.prank(admin);
        experience.removeItemOrClassRequirement(1, tokenId);

        modifiedItem = experience.getItemById(1);
        assertEq(modifiedItem.requirements.length, 1, 'requirement not removed');
        assertEq(modifiedItem.requirements[0][0], 0, 'wrong requirement removed');
        assertEq(modifiedItem.requirements[0][1], 100, 'Incorrect remaining amount');
    }

}
