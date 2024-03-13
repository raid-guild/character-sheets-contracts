// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
pragma abicoder v2;

import "forge-std/Test.sol";
// import "forge-std/console2.sol";

import "./setup/SetUp.t.sol";

contract CharacterAccountTest is SetUp {
    function testEquipItemToCharacter() public {
        dao.addMember(accounts.rando);
        vm.prank(accounts.rando);
        uint256 tokenId = deployments.characterSheets.rollCharacterSheet("new_test_token_uri/");
        assertEq(tokenId, 2, "characterId not assigned");

        assertEq(deployments.characterSheets.tokenURI(tokenId), "test_base_uri_character_sheets/new_test_token_uri/");

        CharacterSheet memory sheet = deployments.characterSheets.getCharacterSheetByCharacterId(tokenId);

        CharacterAccount account = CharacterAccount(payable(sheet.accountAddress));

        vm.startPrank(accounts.gameMaster);
        dropExp(address(account), 1000, address(deployments.experience));
        dropItems(address(account), itemsData.itemIdFree, 1, address(deployments.items));
        vm.stopPrank();

        bytes4 selector = bytes4(keccak256("equipItemToCharacter(uint256,uint256)"));
        bytes memory data = abi.encodeWithSelector(selector, tokenId, itemsData.itemIdFree);

        vm.prank(accounts.rando);
        account.execute(address(deployments.characterSheets), 0, data, 0);

        sheet = deployments.characterSheets.getCharacterSheetByCharacterId(tokenId);
        assertEq(sheet.inventory.length, 1, "item not assigned");
        assertEq(sheet.inventory[0], 3, "item id incorrect");
    }

    function testUnequipItemToCharacter() public {
        dao.addMember(accounts.rando);
        vm.prank(accounts.rando);
        uint256 tokenId = deployments.characterSheets.rollCharacterSheet("test_token_uri/");
        assertEq(tokenId, 2, "characterId not assigned");

        assertEq(deployments.characterSheets.tokenURI(tokenId), "test_base_uri_character_sheets/test_token_uri/");

        CharacterSheet memory sheet = deployments.characterSheets.getCharacterSheetByCharacterId(tokenId);

        CharacterAccount account = CharacterAccount(payable(sheet.accountAddress));

        vm.startPrank(accounts.gameMaster);
        dropExp(address(account), 1000, address(deployments.experience));
        dropItems(address(account), itemsData.itemIdFree, 1, address(deployments.items));
        vm.stopPrank();

        bytes4 selector = bytes4(keccak256("equipItemToCharacter(uint256,uint256)"));
        bytes memory data = abi.encodeWithSelector(selector, tokenId, itemsData.itemIdFree);

        vm.prank(accounts.rando);
        account.execute(address(deployments.characterSheets), 0, data, 0);

        sheet = deployments.characterSheets.getCharacterSheetByCharacterId(tokenId);
        assertEq(sheet.inventory.length, 1, "item not assigned");
        assertEq(sheet.inventory[0], itemsData.itemIdFree, "item not equipped");

        selector = bytes4(keccak256("unequipItemFromCharacter(uint256,uint256)"));
        data = abi.encodeWithSelector(selector, tokenId, itemsData.itemIdFree);

        vm.prank(accounts.rando);
        account.execute(address(deployments.characterSheets), 0, data, 0);

        sheet = deployments.characterSheets.getCharacterSheetByCharacterId(1);
        assertEq(sheet.inventory.length, 0, "item still assigned");
    }

    function testEquipViaMultiSendDelegateCall() public {
        dao.addMember(accounts.rando);
        vm.prank(accounts.rando);
        uint256 tokenId = deployments.characterSheets.rollCharacterSheet("test_token_uri/");
        assertEq(tokenId, 2, "characterId not assigned");

        assertEq(deployments.characterSheets.tokenURI(tokenId), "test_base_uri_character_sheets/test_token_uri/");

        CharacterSheet memory sheet = deployments.characterSheets.getCharacterSheetByCharacterId(tokenId);

        CharacterAccount account = CharacterAccount(payable(sheet.accountAddress));

        vm.startPrank(accounts.gameMaster);
        dropExp(address(account), 1000, address(deployments.experience));
        dropItems(address(account), itemsData.itemIdFree, 1, address(deployments.items));
        vm.stopPrank();

        bytes4 selector = bytes4(keccak256("equipItemToCharacter(uint256,uint256)"));
        bytes memory data = abi.encodeWithSelector(selector, tokenId, itemsData.itemIdFree);

        bytes memory transaction =
            abi.encodePacked(uint8(0), address(deployments.characterSheets), uint256(0), uint256(data.length), data);

        selector = bytes4(keccak256("multiSend(bytes)"));
        data = abi.encodeWithSelector(selector, transaction);

        vm.startPrank(accounts.rando);
        account.execute(address(multisend), itemsData.itemIdFree, data, 1);

        sheet = deployments.characterSheets.getCharacterSheetByCharacterId(tokenId);
        assertEq(sheet.inventory.length, 1, "inventory wrong length");
        assertEq(sheet.inventory[0], itemsData.itemIdFree, "item not equipped");
    }

    function testEquipAndUnequipViaMultiSendDelegateCall() public {
        dao.addMember(accounts.rando);
        vm.prank(accounts.rando);
        uint256 tokenId = deployments.characterSheets.rollCharacterSheet("test_token_uri/");
        assertEq(tokenId, 2, "characterId not assigned");

        assertEq(deployments.characterSheets.tokenURI(tokenId), "test_base_uri_character_sheets/test_token_uri/");

        CharacterSheet memory sheet = deployments.characterSheets.getCharacterSheetByCharacterId(tokenId);

        CharacterAccount account = CharacterAccount(payable(sheet.accountAddress));

        vm.startPrank(accounts.gameMaster);
        dropExp(address(account), 1000, address(deployments.experience));
        dropItems(address(account), itemsData.itemIdFree, 1, address(deployments.items));
        vm.stopPrank();

        bytes4 selector = bytes4(keccak256("equipItemToCharacter(uint256,uint256)"));
        bytes memory data = abi.encodeWithSelector(selector, tokenId, itemsData.itemIdFree);

        bytes memory transaction1 =
            abi.encodePacked(uint8(0), address(deployments.characterSheets), uint256(0), uint256(data.length), data);

        selector = bytes4(keccak256("unequipItemFromCharacter(uint256,uint256)"));
        data = abi.encodeWithSelector(selector, tokenId, itemsData.itemIdFree);

        bytes memory transaction2 =
            abi.encodePacked(uint8(0), address(deployments.characterSheets), uint256(0), uint256(data.length), data);

        bytes memory transaction = abi.encodePacked(transaction1, transaction2);

        selector = bytes4(keccak256("multiSend(bytes)"));
        data = abi.encodeWithSelector(selector, transaction);

        vm.prank(accounts.rando);
        account.execute(address(multisend), 0, data, 1);

        sheet = deployments.characterSheets.getCharacterSheetByCharacterId(tokenId);
        assertEq(sheet.inventory.length, 0, "item still assigned");
    }

    function test_Owner() public {
        dao.addMember(accounts.rando);
        vm.prank(accounts.rando);
        uint256 tokenId = deployments.characterSheets.rollCharacterSheet("test_token_uri/");
        assertEq(tokenId, 2, "characterId not assigned");
        address char = deployments.characterSheets.getCharacterSheetByCharacterId(tokenId).accountAddress;
        CharacterAccount account = CharacterAccount(payable(char));
        assertEq(account.owner(), accounts.rando, "incorrect owner");
    }
}
