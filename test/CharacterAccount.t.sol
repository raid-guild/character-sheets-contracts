// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
pragma abicoder v2;
//solhint-disable

import "forge-std/Test.sol";
import "forge-std/console2.sol";

import "./helpers/SetUp.sol";
import "../src/lib/Errors.sol";

contract CharacterAccountTest is Test, SetUp {
    function testEquipItemToCharacter() public {
        bytes memory encodedData = abi.encode("test_token_uri/");

        vm.prank(admin);
        characterSheets.rollCharacterSheet(admin, encodedData);

        assertEq(characterSheets.tokenURI(2), "test_base_uri_character_sheets/test_token_uri/");

        CharacterSheet memory sheet = characterSheets.getCharacterSheetByCharacterId(2);
        assertEq(sheet.tokenId, 2, "characterId not assigned");
        assertEq(sheet.memberAddress, admin, "memberAddress not assigned");

        CharacterAccount account = CharacterAccount(payable(sheet.erc6551TokenAddress));

        dropExp(address(account), 1000);
        dropItems(address(account), 0, 1);

        bytes4 selector = bytes4(keccak256("equipItemToCharacter(uint256,uint256)"));
        bytes memory data = abi.encodeWithSelector(selector, 2, 0);

        vm.prank(admin);
        account.execute(address(characterSheets), 0, data, 0);

        sheet = characterSheets.getCharacterSheetByCharacterId(2);
        assertEq(sheet.inventory.length, 1, "item not assigned");
        assertEq(sheet.inventory[0], 0, "item not assigned");
    }

    function testUnequipItemToCharacter() public {
        bytes memory encodedData = abi.encode("test_token_uri/");

        vm.prank(admin);
        characterSheets.rollCharacterSheet(admin, encodedData);

        assertEq(characterSheets.tokenURI(2), "test_base_uri_character_sheets/test_token_uri/");

        CharacterSheet memory sheet = characterSheets.getCharacterSheetByCharacterId(2);
        assertEq(sheet.tokenId, 2, "characterId not assigned");
        assertEq(sheet.memberAddress, admin, "memberAddress not assigned");

        CharacterAccount account = CharacterAccount(payable(sheet.erc6551TokenAddress));

        dropExp(address(account), 1000);
        dropItems(address(account), 0, 1);

        bytes4 selector = bytes4(keccak256("equipItemToCharacter(uint256,uint256)"));
        bytes memory data = abi.encodeWithSelector(selector, 2, 0);

        vm.prank(admin);
        account.execute(address(characterSheets), 0, data, 0);

        sheet = characterSheets.getCharacterSheetByCharacterId(2);
        assertEq(sheet.inventory.length, 1, "item not assigned");
        assertEq(sheet.inventory[0], 0, "item not assigned");

        selector = bytes4(keccak256("unequipItemFromCharacter(uint256,uint256)"));
        data = abi.encodeWithSelector(selector, 2, 0);

        vm.prank(admin);
        account.execute(address(characterSheets), 0, data, 0);

        sheet = characterSheets.getCharacterSheetByCharacterId(2);
        assertEq(sheet.inventory.length, 0, "item still assigned");
    }

    function testEquipViaMultiSendDelegateCall() public {
        bytes memory encodedData = abi.encode("test_token_uri/");

        vm.prank(admin);
        characterSheets.rollCharacterSheet(admin, encodedData);

        assertEq(characterSheets.tokenURI(2), "test_base_uri_character_sheets/test_token_uri/");

        CharacterSheet memory sheet = characterSheets.getCharacterSheetByCharacterId(2);
        assertEq(sheet.tokenId, 2, "characterId not assigned");
        assertEq(sheet.memberAddress, admin, "memberAddress not assigned");

        CharacterAccount account = CharacterAccount(payable(sheet.erc6551TokenAddress));

        dropExp(address(account), 1000);
        dropItems(address(account), 0, 1);

        bytes4 selector = bytes4(keccak256("equipItemToCharacter(uint256,uint256)"));
        bytes memory data = abi.encodeWithSelector(selector, 2, 0);

        bytes memory transaction =
            abi.encodePacked(uint8(0), address(characterSheets), uint256(0), uint256(data.length), data);

        selector = bytes4(keccak256("multiSend(bytes)"));
        data = abi.encodeWithSelector(selector, transaction);

        vm.prank(admin);
        account.execute(address(multiSend), 0, data, 1);

        sheet = characterSheets.getCharacterSheetByCharacterId(2);
        assertEq(sheet.inventory.length, 1, "item not assigned");
        assertEq(sheet.inventory[0], 0, "item not assigned");
    }

    function testEquipAndUnequipViaMultiSendDelegateCall() public {
        bytes memory encodedData = abi.encode("test_token_uri/");

        vm.prank(admin);
        characterSheets.rollCharacterSheet(admin, encodedData);

        assertEq(characterSheets.tokenURI(2), "test_base_uri_character_sheets/test_token_uri/");

        CharacterSheet memory sheet = characterSheets.getCharacterSheetByCharacterId(2);
        assertEq(sheet.tokenId, 2, "characterId not assigned");
        assertEq(sheet.memberAddress, admin, "memberAddress not assigned");

        CharacterAccount account = CharacterAccount(payable(sheet.erc6551TokenAddress));

        dropExp(address(account), 1000);
        dropItems(address(account), 0, 1);

        bytes4 selector = bytes4(keccak256("equipItemToCharacter(uint256,uint256)"));
        bytes memory data = abi.encodeWithSelector(selector, 2, 0);

        bytes memory transaction1 =
            abi.encodePacked(uint8(0), address(characterSheets), uint256(0), uint256(data.length), data);

        selector = bytes4(keccak256("unequipItemFromCharacter(uint256,uint256)"));
        data = abi.encodeWithSelector(selector, 2, 0);

        bytes memory transaction2 =
            abi.encodePacked(uint8(0), address(characterSheets), uint256(0), uint256(data.length), data);

        bytes memory transaction = abi.encodePacked(transaction1, transaction2);

        selector = bytes4(keccak256("multiSend(bytes)"));
        data = abi.encodeWithSelector(selector, transaction);

        vm.prank(admin);
        account.execute(address(multiSend), 0, data, 1);

        sheet = characterSheets.getCharacterSheetByCharacterId(2);
        assertEq(sheet.inventory.length, 0, "item still assigned");
    }
}
