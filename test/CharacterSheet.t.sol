// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
pragma abicoder v2;

import "forge-std/Test.sol";
import "forge-std/console2.sol";

import "./setup/SetUp.sol";

import {IERC721Errors} from "openzeppelin-contracts/interfaces/draft-IERC6093.sol";

contract CharacterSheetsTest is SetUp {
    event ItemsUpdated(address exp);

    function testRollCharacterSheet() public {
        dao.addMember(accounts.admin);
        vm.prank(accounts.admin);
        uint256 tokenId = deployments.characterSheets.rollCharacterSheet("test_token_uri/");

        assertEq(tokenId, 2, "Incorrect tokenId");
        assertEq(deployments.characterSheets.tokenURI(2), "test_base_uri_character_sheets/test_token_uri/");
    }

    function testChangeBaseUri() public {
        string memory newBaseUri = "new_base_uri/";
        vm.prank(accounts.admin);
        deployments.characterSheets.updateBaseUri(newBaseUri);
        assertEq(deployments.characterSheets.baseTokenURI(), "new_base_uri/");
    }

    function testEquipItemToCharacter() public {
        vm.startPrank(accounts.gameMaster);
        dropExp(accounts.character1, 1000, address(deployments.experience));
        dropItems(accounts.character1, itemsData.itemIdFree, 1, address(deployments.items));
        vm.stopPrank();
        vm.prank(accounts.character1);
        deployments.characterSheets.equipItemToCharacter(sheetsData.characterId1, itemsData.itemIdFree);

        CharacterSheet memory sheet =
            deployments.characterSheets.getCharacterSheetByCharacterId(sheetsData.characterId1);
        assertEq(sheet.inventory.length, 1, "item not assigned");
        assertEq(sheet.inventory[0], itemsData.itemIdFree, "item not assigned");
    }

    function testUnequipItemFromCharacter() public {
        vm.startPrank(accounts.gameMaster);
        dropExp(accounts.character1, 1000, address(deployments.experience));
        dropItems(accounts.character1, itemsData.itemIdFree, 1, address(deployments.items));
        vm.stopPrank();

        vm.prank(accounts.character1);
        deployments.characterSheets.equipItemToCharacter(sheetsData.characterId1, itemsData.itemIdFree);

        CharacterSheet memory sheet =
            deployments.characterSheets.getCharacterSheetByCharacterId(sheetsData.characterId1);
        assertEq(sheet.inventory.length, 1, "item not assigned");
        assertEq(sheet.inventory[0], itemsData.itemIdFree, "item not assigned");

        vm.prank(accounts.character1);
        deployments.characterSheets.unequipItemFromCharacter(sheetsData.characterId1, itemsData.itemIdFree);

        sheet = deployments.characterSheets.getCharacterSheetByCharacterId(sheetsData.characterId1);
        assertEq(sheet.inventory.length, 0, "item still assigned");
    }

    function testRenounceSheet() public {
        vm.prank(accounts.player1);
        deployments.characterSheets.renounceSheet();

        assertEq(deployments.characterSheets.balanceOf(accounts.player1), 0, "sheet not renounced");
    }

    function testRestoreSheetAfterRenounce() public {
        vm.prank(accounts.player1);
        deployments.characterSheets.renounceSheet();

        assertEq(deployments.characterSheets.balanceOf(accounts.player1), 0, "sheet not renounced");

        // test that account is correctly restored
        vm.prank(accounts.player1);
        address restored = deployments.characterSheets.restoreSheet();

        assertEq(accounts.character1, restored, "Incorrect Address restored");
        assertEq(deployments.characterSheets.balanceOf(accounts.player1), 1, "sheet not restored");

        vm.prank(accounts.rando);
        vm.expectRevert();
        deployments.characterSheets.restoreSheet();

        dao.addMember(accounts.rando);

        vm.prank(accounts.rando);
        uint256 tokenId = deployments.characterSheets.rollCharacterSheet("test_token_uri/");
        assertEq(tokenId, 2, "characterId not assigned");

        vm.prank(accounts.rando);
        deployments.characterSheets.renounceSheet();

        assertEq(deployments.characterSheets.balanceOf(accounts.rando), 0, "sheet not renounced");

        vm.prank(accounts.rando);
        restored = deployments.characterSheets.restoreSheet();

        address npc2 = deployments.characterSheets.getCharacterSheetByCharacterId(2).accountAddress;

        assertEq(npc2, restored, "Second Incorrect Address restored");
        assertEq(deployments.characterSheets.balanceOf(accounts.rando), 1, "sheet not restored");
        assertEq(deployments.hatsAdaptor.isPlayer(accounts.rando), true, "player hat not restored");
        assertEq(deployments.hatsAdaptor.isCharacter(npc2), true, "character hat not restored");
    }

    function testRemovePlayer() public {
        vm.prank(accounts.gameMaster);
        vm.expectRevert(); // still eligible by adapter
        deployments.characterSheets.removeSheet(sheetsData.characterId1);

        dao.jailMember(accounts.player1);

        vm.prank(accounts.gameMaster);
        vm.expectRevert(); // jailed
        deployments.characterSheets.removeSheet(sheetsData.characterId1);

        vm.prank(accounts.gameMaster);
        deployments.characterSheets.jailPlayer(accounts.player1, true);

        vm.prank(accounts.gameMaster);
        deployments.characterSheets.removeSheet(sheetsData.characterId1);

        assertEq(deployments.characterSheets.balanceOf(accounts.player1), 0, "Player 1 has not been removed");
        assertEq(deployments.hatsAdaptor.isPlayer(accounts.player1), false, "player hat not removed");

        vm.prank(accounts.gameMaster);
        vm.expectRevert();
        deployments.characterSheets.removeSheet(sheetsData.characterId2);

        vm.prank(accounts.gameMaster);
        dao.addMember(accounts.rando);

        vm.prank(accounts.rando);
        uint256 tokenId = deployments.characterSheets.rollCharacterSheet("test_token_uri/");
        assertEq(tokenId, 2, "characterId not assigned");

        vm.prank(accounts.gameMaster);
        dao.jailMember(accounts.rando);

        vm.prank(accounts.gameMaster);
        deployments.characterSheets.jailPlayer(accounts.rando, true);

        vm.prank(accounts.gameMaster);
        deployments.characterSheets.removeSheet(tokenId);

        assertEq(deployments.characterSheets.balanceOf(accounts.rando), 0, "Player 2 has not been removed");

        vm.prank(accounts.rando);
        vm.expectRevert();
        deployments.characterSheets.rollCharacterSheet("test_token_uri/");
    }

    function testRestoreSheetAfterRemove() public {
        vm.prank(accounts.gameMaster);
        dao.jailMember(accounts.player1);

        vm.prank(accounts.gameMaster);
        deployments.characterSheets.jailPlayer(accounts.player1, true);

        vm.prank(accounts.gameMaster);
        deployments.characterSheets.removeSheet(0);

        assertEq(deployments.characterSheets.balanceOf(accounts.player1), 0, "Player 1 has not been removed");

        vm.prank(accounts.player1);
        vm.expectRevert(); // still jailed & ineligible
        deployments.characterSheets.restoreSheet();

        vm.prank(accounts.gameMaster);
        dao.unjailMember(accounts.player1);

        vm.prank(accounts.player1);
        vm.expectRevert(); // still jailed
        deployments.characterSheets.restoreSheet();

        vm.prank(accounts.gameMaster);
        deployments.characterSheets.jailPlayer(accounts.player1, false);

        vm.prank(accounts.player1);
        address restored = deployments.characterSheets.restoreSheet();

        assertEq(accounts.character1, restored, "Incorrect Address restored");
        assertEq(deployments.characterSheets.balanceOf(accounts.player1), 1, "sheet not restored");

        vm.prank(accounts.gameMaster);
        dao.addMember(accounts.rando);

        vm.prank(accounts.rando);
        uint256 tokenId = deployments.characterSheets.rollCharacterSheet("test_token_uri/");
        assertEq(tokenId, 2, "characterId not assigned");

        vm.prank(accounts.gameMaster);
        dao.jailMember(accounts.rando);

        vm.prank(accounts.gameMaster);
        deployments.characterSheets.jailPlayer(accounts.rando, true);

        vm.prank(accounts.gameMaster);
        deployments.characterSheets.removeSheet(tokenId);

        assertEq(deployments.characterSheets.balanceOf(accounts.rando), 0, "Player 2 has not been removed");

        vm.prank(accounts.gameMaster);
        dao.unjailMember(accounts.rando);

        vm.prank(accounts.gameMaster);
        deployments.characterSheets.jailPlayer(accounts.rando, false);

        vm.prank(accounts.rando);
        restored = deployments.characterSheets.restoreSheet();

        address npc2 = deployments.characterSheets.getCharacterSheetByCharacterId(tokenId).accountAddress;

        assertEq(npc2, restored, "Incorrect Address restored");
        assertEq(deployments.characterSheets.balanceOf(accounts.rando), 1, "sheet not restored");
    }

    function testGetCharacterSheetByCharacterId() public {
        CharacterSheet memory sheet = deployments.characterSheets.getCharacterSheetByCharacterId(0);
        assertEq(sheet.accountAddress, accounts.character1);
    }

    function testGetPlayerIdFromAccountAddress() public {
        CharacterSheet memory sheet = deployments.characterSheets.getCharacterSheetByCharacterId(0);
        assertEq(accounts.character1, sheet.accountAddress, "Incorrect account address");

        assertEq(
            deployments.characterSheets.getCharacterIdByAccountAddress(accounts.character1), 0, "Incorrect playerId"
        );
    }

    function testUpdateCharacterMetadata() public {
        vm.prank(accounts.player1);
        deployments.characterSheets.updateCharacterMetadata("new_cid");

        string memory uri = deployments.characterSheets.tokenURI(0);
        assertEq(uri, "test_base_uri_character_sheets/new_cid", "Incorrect token uri");

        vm.prank(accounts.rando);
        vm.expectRevert(Errors.PlayerOnly.selector);
        deployments.characterSheets.updateCharacterMetadata("new_cid");
    }

    function testUpdateContractImplementation() public {
        address newSheetImp = address(new CharacterSheetsImplementation());
        HatsData memory hatsData = deployments.hatsAdaptor.getHatsData();
        //should revert if called by non admin
        vm.prank(accounts.player1);
        vm.expectRevert(Errors.AdminOnly.selector);
        deployments.characterSheets.upgradeToAndCall(newSheetImp, "");

        address[] memory newAdmins = new address[](1);
        newAdmins[0] = accounts.player1;
        assertTrue(hatsContracts.hats.isWearerOfHat(accounts.admin, hatsData.adminHatId), "admin not admin");
        address dungHatElig = deployments.hatsAdaptor.gameMasterHatEligibilityModule();

        vm.startPrank(accounts.admin);
        //admin adds player1 to eligible addresses array in admins module.
        AddressHatsEligibilityModule(dungHatElig).addEligibleAddresses(newAdmins);

        // admin mints dmHat to player1
        hatsContracts.hats.mintHat(hatsData.gameMasterHatId, accounts.player1);
        vm.stopPrank();

        //should revert if called by dm;
        vm.expectRevert(Errors.AdminOnly.selector);
        vm.prank(accounts.player1);
        deployments.characterSheets.upgradeToAndCall(newSheetImp, "");

        //should succeed if called by admin
        vm.prank(accounts.admin);
        deployments.characterSheets.upgradeToAndCall(newSheetImp, "");
    }

    //UNHAPPY PATH
    function testRollCharacterSheetFailNonMember() public {
        vm.prank(accounts.rando);
        vm.expectRevert(Errors.EligibilityError.selector);
        deployments.characterSheets.rollCharacterSheet("test_token_uri/");
    }

    function testRollCharacterSheetRevertAlreadyACharacter() public {
        vm.prank(accounts.player1);
        vm.expectRevert(Errors.TokenBalanceError.selector);
        deployments.characterSheets.rollCharacterSheet("test_token_uri/");
    }

    function testChangeBaseUriRevertNotAdmin() public {
        string memory newBaseUri = "new_base_uri/";
        vm.prank(accounts.player1);
        vm.expectRevert(Errors.AdminOnly.selector);
        deployments.characterSheets.updateBaseUri(newBaseUri);
        assertEq(deployments.characterSheets.baseTokenURI(), "test_base_uri_character_sheets/");
    }

    function testEquipItemToCharacterReverts() public {
        vm.prank(accounts.rando);
        vm.expectRevert(Errors.CharacterOnly.selector);
        deployments.characterSheets.equipItemToCharacter(0, 0);

        CharacterSheet memory sheet = deployments.characterSheets.getCharacterSheetByCharacterId(0);
        assertEq(sheet.inventory.length, 0, "item should not be assigned");

        vm.prank(accounts.character2);
        vm.expectRevert(Errors.OwnershipError.selector);
        deployments.characterSheets.equipItemToCharacter(0, 0);

        sheet = deployments.characterSheets.getCharacterSheetByCharacterId(0);
        assertEq(sheet.inventory.length, 0, "item should not be assigned");

        vm.prank(accounts.character1);
        vm.expectRevert(Errors.InsufficientBalance.selector);
        deployments.characterSheets.equipItemToCharacter(0, 0);

        sheet = deployments.characterSheets.getCharacterSheetByCharacterId(0);
        assertEq(sheet.inventory.length, 0, "item should not be assigned");
    }

    function testRenounceSheetReverts() public {
        //revert no sheet
        vm.prank(accounts.rando);
        vm.expectRevert(Errors.PlayerOnly.selector);
        deployments.characterSheets.renounceSheet();

        assertEq(deployments.characterSheets.balanceOf(accounts.player1), 1, "Sheets renounced");
    }

    function testRollFailsForRenouncedSheet() public {
        vm.prank(accounts.player1);
        deployments.characterSheets.renounceSheet();

        assertEq(deployments.characterSheets.balanceOf(accounts.player1), 0, "sheet not renounced");

        vm.prank(accounts.player1);
        vm.expectRevert();
        deployments.characterSheets.rollCharacterSheet("test_token_uri/");
    }

    function testTransferFrom() public {
        assertEq(deployments.characterSheets.balanceOf(accounts.player1), 1, "Incorrect balance for player 1");
        assertEq(deployments.hatsAdaptor.isPlayer(accounts.player1), true, "player 1 is not a player");
        assertEq(deployments.hatsAdaptor.isCharacter(accounts.character1), true, "char 1 not a character");

        assertEq(deployments.characterSheets.balanceOf(accounts.player2), 1, "Incorrect balance for player 2");
        assertEq(deployments.hatsAdaptor.isPlayer(accounts.player2), true, "player 2 is not a player");

        assertEq(deployments.characterSheets.balanceOf(accounts.rando), 0, "Incorrect balance for rando");
        assertEq(deployments.hatsAdaptor.isPlayer(accounts.rando), false, "rando is a player");

        assertEq(
            deployments.characterSheets.getCharacterIdByPlayerAddress(accounts.player1), 0, "Incorrect characterId"
        );
        assertEq(
            deployments.characterSheets.getCharacterSheetByCharacterId(0).accountAddress,
            accounts.character1,
            "Incorrect account1 address"
        );
        assertEq(
            deployments.characterSheets.getCharacterSheetByCharacterId(0).playerAddress,
            accounts.player1,
            "Incorrect player1 address"
        );

        assertEq(
            deployments.characterSheets.getCharacterIdByPlayerAddress(accounts.player2), 1, "Incorrect characterId"
        );
        assertEq(
            deployments.characterSheets.getCharacterSheetByCharacterId(1).accountAddress,
            accounts.character2,
            "Incorrect account2 address"
        );
        assertEq(
            deployments.characterSheets.getCharacterSheetByCharacterId(1).playerAddress,
            accounts.player2,
            "Incorrect player2 address"
        );

        vm.prank(accounts.player1);
        vm.expectRevert(Errors.GameMasterOnly.selector);
        deployments.characterSheets.transferFrom(accounts.player1, accounts.player2, 0);

        vm.prank(accounts.gameMaster);
        vm.expectRevert(Errors.TokenBalanceError.selector);
        deployments.characterSheets.transferFrom(accounts.player1, accounts.player2, 0);

        vm.prank(accounts.gameMaster);
        vm.expectRevert(
            abi.encodeWithSelector(IERC721Errors.ERC721InsufficientApproval.selector, accounts.gameMaster, 0)
        );
        deployments.characterSheets.transferFrom(accounts.player1, accounts.rando, 0);

        vm.prank(accounts.player1);
        deployments.characterSheets.approve(accounts.gameMaster, 0);

        vm.prank(accounts.gameMaster);
        deployments.characterSheets.transferFrom(accounts.player1, accounts.rando, 0);

        assertEq(deployments.characterSheets.balanceOf(accounts.player1), 0, "Incorrect balance");
        assertEq(deployments.hatsAdaptor.isPlayer(accounts.player1), false, "player 1 is a player");
        assertEq(deployments.hatsAdaptor.isCharacter(accounts.character1), true, "char 1 is not a character");

        assertEq(deployments.characterSheets.balanceOf(accounts.rando), 1, "Incorrect balance");
        assertEq(deployments.hatsAdaptor.isPlayer(accounts.rando), true, "rando is not a player");

        assertEq(deployments.characterSheets.getCharacterIdByPlayerAddress(accounts.rando), 0, "Incorrect characterId");
        assertEq(
            deployments.characterSheets.getCharacterSheetByCharacterId(0).accountAddress,
            accounts.character1,
            "Incorrect account address"
        );
        assertEq(
            deployments.characterSheets.getCharacterSheetByCharacterId(0).playerAddress,
            accounts.rando,
            "Incorrect player address"
        );
    }

    function testSafeTransferFrom() public {
        assertEq(deployments.characterSheets.balanceOf(accounts.player1), 1, "Incorrect balance for player 1");
        assertEq(deployments.hatsAdaptor.isPlayer(accounts.player1), true, "player 1 is not a player");
        assertEq(deployments.hatsAdaptor.isCharacter(accounts.character1), true, "char 1 not a character");

        assertEq(deployments.characterSheets.balanceOf(accounts.player2), 1, "Incorrect balance for player 2");
        assertEq(deployments.hatsAdaptor.isPlayer(accounts.player2), true, "player 2 is not a player");

        assertEq(deployments.characterSheets.balanceOf(accounts.rando), 0, "Incorrect balance for rando");
        assertEq(deployments.hatsAdaptor.isPlayer(accounts.rando), false, "rando is a player");

        assertEq(
            deployments.characterSheets.getCharacterIdByPlayerAddress(accounts.player1), 0, "Incorrect characterId"
        );
        assertEq(
            deployments.characterSheets.getCharacterSheetByCharacterId(0).accountAddress,
            accounts.character1,
            "Incorrect account1 address"
        );
        assertEq(
            deployments.characterSheets.getCharacterSheetByCharacterId(0).playerAddress,
            accounts.player1,
            "Incorrect player1 address"
        );

        assertEq(
            deployments.characterSheets.getCharacterIdByPlayerAddress(accounts.player2), 1, "Incorrect characterId"
        );
        assertEq(
            deployments.characterSheets.getCharacterSheetByCharacterId(1).accountAddress,
            accounts.character2,
            "Incorrect account2 address"
        );
        assertEq(
            deployments.characterSheets.getCharacterSheetByCharacterId(1).playerAddress,
            accounts.player2,
            "Incorrect player2 address"
        );

        // console.log("OWNER OF: ", deployments.characterSheets.ownerOf(1));

        vm.prank(accounts.player1);
        vm.expectRevert(Errors.GameMasterOnly.selector);
        deployments.characterSheets.safeTransferFrom(accounts.player1, accounts.player2, 0);

        vm.prank(accounts.gameMaster);
        vm.expectRevert(Errors.TokenBalanceError.selector);
        deployments.characterSheets.safeTransferFrom(accounts.player1, accounts.player2, 0);

        vm.prank(accounts.gameMaster);
        vm.expectRevert(
            abi.encodeWithSelector(IERC721Errors.ERC721InsufficientApproval.selector, accounts.gameMaster, 0)
        );
        deployments.characterSheets.safeTransferFrom(accounts.player1, accounts.rando, 0);

        vm.prank(accounts.player1);
        deployments.characterSheets.approve(accounts.gameMaster, 0);

        vm.prank(accounts.gameMaster);
        deployments.characterSheets.safeTransferFrom(accounts.player1, accounts.rando, 0);

        assertEq(deployments.characterSheets.balanceOf(accounts.player1), 0, "Incorrect balance");
        assertEq(deployments.hatsAdaptor.isPlayer(accounts.player1), false, "player 1 is a player");
        assertEq(deployments.hatsAdaptor.isCharacter(accounts.character1), true, "char 1 is not a character");

        assertEq(deployments.characterSheets.balanceOf(accounts.rando), 1, "Incorrect balance");
        assertEq(deployments.hatsAdaptor.isPlayer(accounts.rando), true, "rando is not a player");

        assertEq(deployments.characterSheets.getCharacterIdByPlayerAddress(accounts.rando), 0, "Incorrect characterId");
        assertEq(
            deployments.characterSheets.getCharacterSheetByCharacterId(0).accountAddress,
            accounts.character1,
            "Incorrect account address"
        );
        assertEq(
            deployments.characterSheets.getCharacterSheetByCharacterId(0).playerAddress,
            accounts.rando,
            "Incorrect player address"
        );
        //transfer character back to original owner

        vm.prank(accounts.rando);
        deployments.characterSheets.approve(accounts.gameMaster, 0);

        vm.prank(accounts.gameMaster);
        deployments.characterSheets.safeTransferFrom(accounts.rando, accounts.player1, 0);
    }

    function testSafeTransferFromBackAndForth() public {
        vm.prank(accounts.player1);
        deployments.characterSheets.approve(accounts.gameMaster, 0);

        vm.prank(accounts.gameMaster);
        deployments.characterSheets.safeTransferFrom(accounts.player1, accounts.rando, 0);

        assertEq(deployments.characterSheets.balanceOf(accounts.player1), 0, "Incorrect balance");
        assertEq(deployments.hatsAdaptor.isPlayer(accounts.player1), false, "player 1 is a player");
        assertEq(deployments.hatsAdaptor.isCharacter(accounts.character1), true, "char 1 is not a character");

        vm.prank(accounts.rando);
        deployments.characterSheets.approve(accounts.gameMaster, 0);
        vm.prank(accounts.gameMaster);
        deployments.characterSheets.safeTransferFrom(accounts.rando, accounts.player1, 0, "");
    }
}
