// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;
pragma abicoder v2;

import "forge-std/Test.sol";
import "./helpers/SetUp.sol";


contract CharacterSheetsTest is Test, SetUp {

    event ExperienceUpdated(address exp);

    function testRollCharacterSheet() public {
        bytes memory encodedData = abi.encode('Test Name', 'test_token_uri/');
        vm.prank(admin);
        characterSheets.rollCharacterSheet(admin, encodedData);

        assertEq(characterSheets.tokenURI(2), 'test_base_uri_character_sheets/test_token_uri/');
    }

    function testRollCharacterSheetFailNonMember() public {
        bytes memory encodedData = abi.encode('Test Name', 'test uri');
        vm.prank(admin);
        vm.expectRevert("Player is not a member of the dao");
        characterSheets.rollCharacterSheet(player2, encodedData );
    }

    function testRollCharacterSheetRevertAlreadyACharacter() public {
        bytes memory encodedData = abi.encode('Test Name', 'test uri');
        vm.prank(admin);
        vm.expectRevert("this player is already in the game");
        characterSheets.rollCharacterSheet(player1, encodedData );
    }

    function testChangeBaseUri() public {
        string memory newBaseUri = 'new_base_uri/';
        vm.prank(admin);
        characterSheets.setBaseUri(newBaseUri);
        assertEq(characterSheets.tokenURI(1), 'new_base_uri/test_token_uri/');
    }

    function testChangeBaseUriAccessControlRevert() public {
        string memory newBaseUri = 'new_base_uri/';
        vm.prank(player1);
        vm.expectRevert("AccessControl: account 0x000000000000000000000000000000000000beef is missing role 0x9f5957e014b94f6c4458eb946e74e5d7e489dfaff6e0bddd07dd7d48100ca913");
        characterSheets.setBaseUri(newBaseUri);

    }

    function testAddClassToPlayer() public {
        vm.prank(address(experience));
        characterSheets.addClassToPlayer(1, 1);

        CharacterSheet memory sheet = characterSheets.getCharacterSheetByPlayerId(1);
        assertEq(sheet.classes[0], 1, "class not assigned");
    }

        function testAddItemToPlayer() public {
        vm.prank(address(experience));
        characterSheets.addItemToPlayer(1, 1);

        CharacterSheet memory sheet = characterSheets.getCharacterSheetByPlayerId(1);
        assertEq(sheet.items[0], 1, "item not assigned");
    }

    function testTransferFromRevert() public {
        vm.prank(player1);
        vm.expectRevert();
        characterSheets.transferFrom(player1, player2, 1);

        vm.prank(admin);
        vm.expectRevert();
        characterSheets.transferFrom(player1, player2, 1);
    }

    function testRenounceSheet()public {
        vm.prank(player1);
        characterSheets.renounceSheet(1);

        assertEq(characterSheets.balanceOf(player1), 0);  

        vm.prank(player2);
        vm.expectRevert();
        characterSheets.renounceSheet(1);   
    }

    function testUpdateExpContract() public {
        vm.expectEmit(false, false, false, true);
        emit ExperienceUpdated(player2);
        vm.prank(admin);
        characterSheets.updateExpContract(player2);
    }

    function testGetCharacterSheetByPlayerId() public {
        CharacterSheet memory sheet = characterSheets.getCharacterSheetByPlayerId(1);
        assertEq(sheet.memberAddress, player1);

        vm.expectRevert("This is not a character.");
        characterSheets.getCharacterSheetByPlayerId(5); 
    }

    function testGetPlayerIdFromNftAddress() public {
        CharacterSheet memory sheet = characterSheets.getCharacterSheetByPlayerId(1);

        uint256 playerId = characterSheets.getPlayerIdByNftAddress(sheet.ERC6551TokenAddress);

        assertEq(playerId, 1, "Incorrect playerId");

        vm.expectRevert("This is not the address of an npc");
        characterSheets.getPlayerIdByNftAddress(player2);
    }

    function testRemovePlayer() public {

        vm.prank(admin);
        vm.expectRevert("There has been no passing guild kick proposal on this player.");
        characterSheets.removePlayer(1);

        dao.jailMember(player1);

        vm.prank(admin);
        characterSheets.removePlayer(1);

        assertEq(characterSheets.balanceOf(player1), 0, "Player has not been removed");

        vm.prank(admin);
        vm.expectRevert("This is not a character.");
        characterSheets.removePlayer(2);
    }

    function testUpdatePlayerName()public {
        vm.prank(player1);
        characterSheets.updatePlayerName("Regard");
        CharacterSheet memory player = characterSheets.getCharacterSheetByPlayerId(1);
        assertEq(player.name, "Regard", "This player is not regarded");

        vm.prank(player2);
        vm.expectRevert("AccessControl: account 0x000000000000000000000000000000000000babe is missing role 0x0f98b3a5774fbfdf19646dba94a6c08f13f4c341502334a57724de46497192c3");
        characterSheets.updatePlayerName("Regard");
    }

    //#TODO add remove class / item from player tests and functions.
}
