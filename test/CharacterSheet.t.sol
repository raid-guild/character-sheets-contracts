// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;
pragma abicoder v2;

import "forge-std/Test.sol";
import "./helpers/SetUp.sol";


contract CharacterSheetsTest is Test, SetUp {

    function testRollCharacterSheet() public {
        bytes memory encodedData = abi.encode('Test Name', 'test_token_uri/');
        vm.prank(admin);
        characterSheets.rollCharacterSheet(player1, encodedData);
        assertEq(characterSheets.tokenURI(2), 'test_base_uri_character_sheets/test_token_uri/');
    }

    function testRollCharacterSheetFailNonMember() public {
        bytes memory encodedData = abi.encode('Test Name', 'test uri');
        vm.prank(admin);
        vm.expectRevert("Player is not a member of the dao");
        characterSheets.rollCharacterSheet(player2, encodedData );
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
}
