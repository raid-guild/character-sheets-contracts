// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;
pragma abicoder v2;

import "forge-std/Test.sol";
import "../src/CharacterSheetsFactory.sol";
import "../src/CharacterSheetsImplementation.sol";
import "../src/interfaces/IMolochDAO.sol";
import "../src/mocks/mockMoloch.sol";
import "@openzeppelin/contracts-upgradeable/proxy/ClonesUpgradeable.sol";
import {ERC6551Registry} from "../src/mocks/ERC6551Registry.sol";
import {SimpleERC6551Account} from "../src/mocks/ERC6551Implementation.sol";


contract CharacterSheetsTest is Test {
    CharacterSheetsFactory characterSheetsFactory;
    CharacterSheetsImplementation characterSheetsImplementation;
    CharacterSheetsImplementation characterSheets;
    address characterSheetsAddress;

    using ClonesUpgradeable for address;

    address admin = address(0xdeadce11);
    address player1 = address(0xbeef);
    address player2 = address(0xbabe);
    Moloch dao;

   

    ERC6551Registry erc6551Registry;
    SimpleERC6551Account erc6551Implementation;

    function setUp() public {
        vm.startPrank(admin);

        dao = new Moloch();
        vm.label(address(dao), 'Moloch');

        characterSheetsFactory= new CharacterSheetsFactory();
        characterSheetsFactory.initialize();

        vm.label(address(characterSheetsFactory), 'Character factory');

        characterSheetsImplementation = new CharacterSheetsImplementation();
        vm.label(address(characterSheetsImplementation), 'CharacterSheets Implementation');

        erc6551Registry = new ERC6551Registry();
        erc6551Implementation = new SimpleERC6551Account();

        dao.addMember(player1);
        characterSheetsFactory.updateCharacterSheetsImplementation(address(characterSheetsImplementation));
        
        bytes memory data = abi.encode(address(dao), admin);

        characterSheetsAddress = characterSheetsFactory.create(data, admin);
        characterSheets = CharacterSheetsImplementation(characterSheetsAddress);
        characterSheets.setERC6551Registry(address(erc6551Registry));
        characterSheets.setERC6551Implementation(address(erc6551Implementation));
        vm.stopPrank();
     }

    function testRollCharacterSheet() public {
        bytes memory encodedData = abi.encode('Test Name',false);
        vm.prank(admin);
        characterSheets.rollCharacterSheet(player1, encodedData );
    }

    function testRollCharacterSheetFail() public {
        bytes memory encodedData = abi.encode('Test Name',false);
        vm.prank(admin);
        vm.expectRevert("player is not a member of the dao");
        characterSheets.rollCharacterSheet(player2, encodedData );
    }
    
}
