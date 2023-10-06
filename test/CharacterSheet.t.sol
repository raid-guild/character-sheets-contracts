// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
pragma abicoder v2;
//solhint-disable

import "forge-std/Test.sol";
import "forge-std/console2.sol";

import "./helpers/SetUp.sol";
import "../src/lib/Errors.sol";

contract CharacterSheetsTest is Test, SetUp {
    event ItemsUpdated(address exp);

    function testRollCharacterSheet() public {
        vm.prank(admin);
        uint256 tokenId = characterSheets.rollCharacterSheet("test_token_uri/");

        assertEq(tokenId, 1, "Incorrect tokenId");
        assertEq(characterSheets.tokenURI(1), "test_base_uri_character_sheets/test_token_uri/");
    }

    function testRollCharacterSheetFailNonMember() public {
        vm.prank(player2);
        vm.expectRevert();
        characterSheets.rollCharacterSheet("test_token_uri/");
    }

    function testRollCharacterSheetRevertAlreadyACharacter() public {
        vm.prank(player1);
        vm.expectRevert();
        characterSheets.rollCharacterSheet("test_token_uri/");
    }

    function testChangeBaseUri() public {
        string memory newBaseUri = "new_base_uri/";
        vm.prank(admin);
        characterSheets.setBaseUri(newBaseUri);
        assertEq(characterSheets.baseTokenURI(), "new_base_uri/");
    }

    function testChangeBaseUriAccessControlRevert() public {
        string memory newBaseUri = "new_base_uri/";
        vm.prank(player1);
        vm.expectRevert(Errors.DungeonMasterOnly.selector);
        characterSheets.setBaseUri(newBaseUri);
    }

    function testEquipItemToCharacter() public {
        dropExp(npc1, 1000);
        dropItems(npc1, 0, 1);

        vm.prank(npc1);
        characterSheets.equipItemToCharacter(0, 0);

        CharacterSheet memory sheet = characterSheets.getCharacterSheetByCharacterId(0);
        assertEq(sheet.inventory.length, 1, "item not assigned");
        assertEq(sheet.inventory[0], 0, "item not assigned");
    }

    function testUnequipItemFromCharacter() public {
        dropExp(npc1, 1000);
        dropItems(npc1, 0, 1);

        vm.prank(npc1);
        characterSheets.equipItemToCharacter(0, 0);

        CharacterSheet memory sheet = characterSheets.getCharacterSheetByCharacterId(0);
        assertEq(sheet.inventory.length, 1, "item not assigned");
        assertEq(sheet.inventory[0], 0, "item not assigned");

        vm.prank(npc1);
        characterSheets.unequipItemFromCharacter(0, 0);

        sheet = characterSheets.getCharacterSheetByCharacterId(0);
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
        characterSheets.renounceSheet();

        assertEq(characterSheets.balanceOf(player1), 0, "sheet not renounced");

        vm.prank(player2);
        vm.expectRevert();
        characterSheets.renounceSheet();

        // roll a new sheet reverts after renouncing / can only be restored
        vm.prank(player1);
        vm.expectRevert();
        characterSheets.rollCharacterSheet("test_token_uri/");

        vm.prank(admin);
        uint256 tokenId = characterSheets.rollCharacterSheet("test_token_uri/");
        assertEq(tokenId, 1, "characterId not assigned");
        assertEq(characterSheets.balanceOf(admin), 1, "sheet not renounced");

        vm.prank(admin);
        characterSheets.renounceSheet();

        assertEq(characterSheets.balanceOf(admin), 0, "sheet not renounced");

        vm.prank(admin);
        vm.expectRevert();
        characterSheets.rollCharacterSheet("test_token_uri/");
    }

    function testRollFailsForRenouncedSheet() public {
        vm.prank(player1);
        characterSheets.renounceSheet();

        assertEq(characterSheets.balanceOf(player1), 0, "sheet not renounced");

        vm.prank(player1);
        vm.expectRevert();
        characterSheets.rollCharacterSheet("test_token_uri/");
    }

    function testRestoreSheetAfterRenounce() public {
        vm.prank(player1);
        characterSheets.renounceSheet();

        assertEq(characterSheets.balanceOf(player1), 0, "sheet not renounced");

        // test that account is correctly restored
        vm.prank(player1);
        address restored = characterSheets.restoreSheet();

        assertEq(npc1, restored, "Incorrect Address restored");
        assertEq(characterSheets.balanceOf(player1), 1, "sheet not restored");

        vm.prank(player2);
        vm.expectRevert();
        characterSheets.restoreSheet();

        vm.prank(admin);
        dao.addMember(player2);

        vm.prank(player2);
        uint256 tokenId = characterSheets.rollCharacterSheet("test_token_uri/");
        assertEq(tokenId, 1, "characterId not assigned");

        vm.prank(player2);
        characterSheets.renounceSheet();

        assertEq(characterSheets.balanceOf(player2), 0, "sheet not renounced");

        vm.prank(player2);
        restored = characterSheets.restoreSheet();

        address npc2 = characterSheets.getCharacterSheetByCharacterId(1).accountAddress;

        assertEq(npc2, restored, "Incorrect Address restored");
        assertEq(characterSheets.balanceOf(player2), 1, "sheet not restored");
    }

    function testRemovePlayer() public {
        vm.prank(admin);
        vm.expectRevert(); // still eligible by adapter
        characterSheets.removeSheet(0);

        vm.prank(admin);
        dao.jailMember(player1);

        vm.prank(admin);
        vm.expectRevert(); // jailed
        characterSheets.removeSheet(0);

        vm.prank(admin);
        characterSheets.jailPlayer(player1, true);

        vm.prank(admin);
        characterSheets.removeSheet(0);

        assertEq(characterSheets.balanceOf(player1), 0, "Player 1 has not been removed");

        vm.prank(admin);
        vm.expectRevert();
        characterSheets.removeSheet(1);

        vm.prank(admin);
        dao.addMember(player2);

        vm.prank(player2);
        uint256 tokenId = characterSheets.rollCharacterSheet("test_token_uri/");
        assertEq(tokenId, 1, "characterId not assigned");

        vm.prank(admin);
        dao.jailMember(player2);

        vm.prank(admin);
        characterSheets.jailPlayer(player2, true);

        vm.prank(admin);
        characterSheets.removeSheet(1);

        assertEq(characterSheets.balanceOf(player2), 0, "Player 2 has not been removed");

        vm.prank(player2);
        vm.expectRevert();
        characterSheets.rollCharacterSheet("test_token_uri/");
    }

    function testRestoreSheetAfterRemove() public {
        vm.prank(admin);
        dao.jailMember(player1);

        vm.prank(admin);
        characterSheets.jailPlayer(player1, true);

        vm.prank(admin);
        characterSheets.removeSheet(0);

        assertEq(characterSheets.balanceOf(player1), 0, "Player 1 has not been removed");

        vm.prank(player1);
        vm.expectRevert(); // still jailed & ineligible
        characterSheets.restoreSheet();

        vm.prank(admin);
        dao.unjailMember(player1);

        vm.prank(player1);
        vm.expectRevert(); // still jailed
        characterSheets.restoreSheet();

        vm.prank(admin);
        characterSheets.jailPlayer(player1, false);

        vm.prank(player1);
        address restored = characterSheets.restoreSheet();

        assertEq(npc1, restored, "Incorrect Address restored");
        assertEq(characterSheets.balanceOf(player1), 1, "sheet not restored");

        vm.prank(admin);
        dao.addMember(player2);

        vm.prank(player2);
        uint256 tokenId = characterSheets.rollCharacterSheet("test_token_uri/");
        assertEq(tokenId, 1, "characterId not assigned");

        vm.prank(admin);
        dao.jailMember(player2);

        vm.prank(admin);
        characterSheets.jailPlayer(player2, true);

        vm.prank(admin);
        characterSheets.removeSheet(1);

        assertEq(characterSheets.balanceOf(player2), 0, "Player 2 has not been removed");

        vm.prank(admin);
        dao.unjailMember(player2);

        vm.prank(admin);
        characterSheets.jailPlayer(player2, false);

        vm.prank(player2);
        restored = characterSheets.restoreSheet();

        address npc2 = characterSheets.getCharacterSheetByCharacterId(1).accountAddress;

        assertEq(npc2, restored, "Incorrect Address restored");
        assertEq(characterSheets.balanceOf(player2), 1, "sheet not restored");
    }

    function testUpdateItemsContract() public {
        vm.expectEmit(false, false, false, true);
        emit ItemsUpdated(player2);
        vm.prank(admin);
        characterSheets.updateItemsContract(player2);
    }

    function testGetCharacterSheetByCharacterId() public {
        CharacterSheet memory sheet = characterSheets.getCharacterSheetByCharacterId(0);
        assertEq(sheet.accountAddress, npc1);

        vm.expectRevert();
        characterSheets.getCharacterSheetByCharacterId(5);
    }

    function testGetPlayerIdFromAccountAddress() public {
        CharacterSheet memory sheet = characterSheets.getCharacterSheetByCharacterId(0);
        assertEq(sheet.accountAddress, npc1, "Incorrect account address");

        assertEq(characterSheets.getCharacterIdByAccountAddress(sheet.accountAddress), 0, "Incorrect playerId");

        assertEq(characterSheets.getCharacterIdByAccountAddress(npc1), 0, "Incorrect playerId");
    }

    function testUpdateCharacterMetadata() public {
        vm.prank(player1);
        characterSheets.updateCharacterMetadata("new_cid");

        string memory uri = characterSheets.tokenURI(0);
        assertEq(uri, "test_base_uri_character_sheets/new_cid", "Incorrect token uri");

        vm.prank(player2);
        vm.expectRevert(Errors.PlayerOnly.selector);
        characterSheets.updateCharacterMetadata("new_cid");
    }
}
