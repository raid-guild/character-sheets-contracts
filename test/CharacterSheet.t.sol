// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
pragma abicoder v2;
//solhint-disable

import "forge-std/Test.sol";
import "./helpers/SetUp.sol";
import "../src/lib/Errors.sol";

import "forge-std/console2.sol";

contract CharacterSheetsTest is Test, SetUp {
    event ItemsUpdated(address exp);

    function testRollCharacterSheet() public {
        bytes memory encodedData = abi.encode("Test Name", "test_token_uri/");
        vm.prank(admin);
        characterSheets.rollCharacterSheet(admin, encodedData);

        assertEq(characterSheets.tokenURI(2), "test_base_uri_character_sheets/test_token_uri/");
    }

    function testRollCharacterSheetFailNonMember() public {
        bytes memory encodedData = abi.encode("Test Name", "test uri");
        vm.prank(admin);
        vm.expectRevert();
        characterSheets.rollCharacterSheet(player2, encodedData);
    }

    function testRollCharacterSheetRevertAlreadyACharacter() public {
        bytes memory encodedData = abi.encode("Test Name", "test uri");
        vm.prank(admin);
        vm.expectRevert();
        characterSheets.rollCharacterSheet(player1, encodedData);
    }

    function testChangeBaseUri() public {
        string memory newBaseUri = "new_base_uri/";
        vm.prank(admin);
        characterSheets.setBaseUri(newBaseUri);
        assertEq(characterSheets.tokenURI(1), "new_base_uri/test_token_uri/");
    }

    function testChangeBaseUriAccessControlRevert() public {
        string memory newBaseUri = "new_base_uri/";
        vm.prank(player1);
        vm.expectRevert(
            "AccessControl: account 0x000000000000000000000000000000000000beef is missing role 0x9f5957e014b94f6c4458eb946e74e5d7e489dfaff6e0bddd07dd7d48100ca913"
        );
        characterSheets.setBaseUri(newBaseUri);
    }

    function testEquipItemToCharacter() public {
        vm.prank(admin);
        address[] memory npc = new address[](1);
        npc[0] = npc1;
        uint256[][] memory itemIds = new uint256[][](1);
        itemIds[0] = new uint256[](1);
        itemIds[0][0] = 1;
        uint256[][] memory amounts = new uint256[][](1);
        amounts[0] = new uint256[](1);
        amounts[0][0] = 1;
        items.dropLoot(npc, itemIds, amounts);
        vm.prank(npc1);
        characterSheets.equipItemToCharacter(1, 1);

        CharacterSheet memory sheet = characterSheets.getCharacterSheetByCharacterId(1);
        assertEq(sheet.inventory[0], 1, "item not assigned");
    }

    function testUnequipItemFromCharacter() public {
        vm.prank(admin);
        address[] memory npc = new address[](1);
        npc[0] = npc1;
        uint256[][] memory itemIds = new uint256[][](1);
        itemIds[0] = new uint256[](1);
        itemIds[0][0] = 1;
        uint256[][] memory amounts = new uint256[][](1);
        amounts[0] = new uint256[](1);
        amounts[0][0] = 1;
        items.dropLoot(npc, itemIds, amounts);
        vm.prank(npc1);
        characterSheets.equipItemToCharacter(1, 1);

        CharacterSheet memory sheet = characterSheets.getCharacterSheetByCharacterId(1);
        assertEq(sheet.inventory.length, 1, "item not assigned");
        assertEq(sheet.inventory[0], 1, "item not assigned");

        vm.prank(npc1);
        characterSheets.unequipItemFromCharacter(1, 1);

        sheet = characterSheets.getCharacterSheetByCharacterId(1);
        assertEq(sheet.inventory.length, 0, "item still assigned");
    }

    function testTransferFromRevert() public {
        vm.prank(player1);
        vm.expectRevert();
        characterSheets.transferFrom(player1, player2, 1);

        vm.prank(admin);
        vm.expectRevert();
        characterSheets.transferFrom(player1, player2, 1);
    }

    function testRenounceSheet() public {
        vm.prank(player1);
        characterSheets.renounceSheet(1);

        assertEq(characterSheets.balanceOf(player1), 0, "sheet not renounced");

        vm.prank(player2);
        vm.expectRevert();
        characterSheets.renounceSheet(1);

        //create a new sheet after renouncing
        bytes memory encodedData = abi.encode("Test Name", "test_token_uri/");
        vm.prank(player1);
        characterSheets.rollCharacterSheet(player1, encodedData);

        assertEq(characterSheets.tokenURI(2), "test_base_uri_character_sheets/test_token_uri/");
    }

    function testRestoreSheet() public {
        address tbaAddress = characterSheets.getCharacterSheetByCharacterId(1).erc6551TokenAddress;
        vm.prank(player1);
        characterSheets.renounceSheet(1);

        assertEq(characterSheets.balanceOf(player1), 0, "sheet not renounced");

        // test that wrong player cannot restore account

        vm.startPrank(player2);
        dao.addMember(player2);
        bytes memory encodedData = abi.encode("Test Name", "test_token_uri/");
        uint256 newTokenId = characterSheets.rollCharacterSheet(player2, encodedData);
        characterSheets.renounceSheet(newTokenId);
        vm.expectRevert();
        characterSheets.restoreSheet(1);
        vm.stopPrank();

        // test that account is correctly restored
        vm.prank(player1);
        address restored = characterSheets.restoreSheet(1);

        assertEq(tbaAddress, restored, "Incorrect Address restored");
    }

    function testUpdateItemsContract() public {
        vm.expectEmit(false, false, false, true);
        emit ItemsUpdated(player2);
        vm.prank(admin);
        characterSheets.updateItemsContract(player2);
    }

    function testGetCharacterSheetByCharacterId() public {
        CharacterSheet memory sheet = characterSheets.getCharacterSheetByCharacterId(1);
        assertEq(sheet.memberAddress, player1);

        vm.expectRevert();
        characterSheets.getCharacterSheetByCharacterId(5);
    }

    function testGetPlayerIdFromNftAddress() public {
        CharacterSheet memory sheet = characterSheets.getCharacterSheetByCharacterId(1);

        uint256 playerId = characterSheets.getCharacterIdByNftAddress(sheet.erc6551TokenAddress);

        assertEq(playerId, 1, "Incorrect playerId");

        vm.expectRevert();
        characterSheets.getCharacterIdByNftAddress(player2);
    }

    function testRemovePlayer() public {
        vm.prank(admin);
        vm.expectRevert();
        characterSheets.removeSheet(1);

        dao.jailMember(player1);

        vm.prank(admin);
        characterSheets.removeSheet(1);

        assertEq(characterSheets.balanceOf(player1), 0, "Player has not been removed");

        vm.prank(admin);
        vm.expectRevert();
        characterSheets.removeSheet(2);
    }

    function testUpdateCharacterMetadata() public {
        vm.prank(player1);
        characterSheets.updateCharacterMetadata("Regard", "new_cid");
        CharacterSheet memory player = characterSheets.getCharacterSheetByCharacterId(1);
        assertEq(player.name, "Regard", "This player is not regarded");

        string memory uri = characterSheets.tokenURI(1);
        assertEq(uri, "test_base_uri_character_sheets/new_cid", "Incorrect token uri");

        vm.prank(player2);
        vm.expectRevert(
            "AccessControl: account 0x000000000000000000000000000000000000babe is missing role 0x0f98b3a5774fbfdf19646dba94a6c08f13f4c341502334a57724de46497192c3"
        );
        characterSheets.updateCharacterMetadata("Regard", "new_cid");
    }
}
