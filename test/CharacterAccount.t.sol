// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
pragma abicoder v2;
//solhint-disable

import "forge-std/Test.sol";
import "./helpers/SetUp.sol";
import "../src/lib/Errors.sol";

import "forge-std/console2.sol";

contract CharacterAccountTest is Test, SetUp {
    function testEquipItemToCharacter() public {
        bytes memory encodedData = abi.encode("Test Name", "test_token_uri/");

        vm.prank(admin);
        characterSheets.rollCharacterSheet(admin, encodedData);

        assertEq(characterSheets.tokenURI(2), "test_base_uri_character_sheets/test_token_uri/");

        CharacterSheet memory sheet = characterSheets.getCharacterSheetByCharacterId(2);
        assertEq(sheet.tokenId, 2, "characterId not assigned");
        assertEq(sheet.memberAddress, admin, "memberAddress not assigned");

        CharacterAccount account = CharacterAccount(payable(sheet.ERC6551TokenAddress));

        address[] memory npc = new address[](1);
        npc[0] = address(account);
        uint256[][] memory itemIds = new uint256[][](1);
        itemIds[0] = new uint256[](1);
        itemIds[0][0] = 1;
        uint256[][] memory amounts = new uint256[][](1);
        amounts[0] = new uint256[](1);
        amounts[0][0] = 1;
        vm.prank(admin);
        experience.dropLoot(npc, itemIds, amounts);

        bytes4 selector = bytes4(keccak256("equipItemToCharacter(uint256,uint256)"));
        bytes memory data = abi.encodeWithSelector(selector, 2, 1);

        vm.prank(admin);
        account.execute(address(characterSheets), 0, data, 0);

        sheet = characterSheets.getCharacterSheetByCharacterId(2);
        assertEq(sheet.inventory[0], 1, "item not assigned");
    }

    function testUnequipItemToCharacter() public {
        bytes memory encodedData = abi.encode("Test Name", "test_token_uri/");

        vm.prank(admin);
        characterSheets.rollCharacterSheet(admin, encodedData);

        assertEq(characterSheets.tokenURI(2), "test_base_uri_character_sheets/test_token_uri/");

        CharacterSheet memory sheet = characterSheets.getCharacterSheetByCharacterId(2);
        assertEq(sheet.tokenId, 2, "characterId not assigned");
        assertEq(sheet.memberAddress, admin, "memberAddress not assigned");

        CharacterAccount account = CharacterAccount(payable(sheet.ERC6551TokenAddress));

        address[] memory npc = new address[](1);
        npc[0] = address(account);
        uint256[][] memory itemIds = new uint256[][](1);
        itemIds[0] = new uint256[](1);
        itemIds[0][0] = 1;
        uint256[][] memory amounts = new uint256[][](1);
        amounts[0] = new uint256[](1);
        amounts[0][0] = 1;
        vm.prank(admin);
        experience.dropLoot(npc, itemIds, amounts);

        bytes4 selector = bytes4(keccak256("equipItemToCharacter(uint256,uint256)"));
        bytes memory data = abi.encodeWithSelector(selector, 2, 1);

        vm.prank(admin);
        account.execute(address(characterSheets), 0, data, 0);

        sheet = characterSheets.getCharacterSheetByCharacterId(2);
        assertEq(sheet.inventory.length, 1, "item not assigned");
        assertEq(sheet.inventory[0], 1, "item not assigned");

        selector = bytes4(keccak256("unequipItemFromCharacter(uint256,uint256)"));
        data = abi.encodeWithSelector(selector, 2, 1);

        vm.prank(admin);
        account.execute(address(characterSheets), 0, data, 0);

        sheet = characterSheets.getCharacterSheetByCharacterId(2);
        assertEq(sheet.inventory.length, 0, "item still assigned");
    }
}
