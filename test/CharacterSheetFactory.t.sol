// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;
pragma abicoder v2;

import "forge-std/Test.sol";
import "./helpers/SetUp.sol";

contract CharacterSheetsTest is Test, SetUp {
    event CharacterSheetsCreated(address newCharacterSheets, address creator);
    event CharacterSheetsUpdated(address newCharacterSheets);
    event ExperienceUpdated(address newExperience);
    event ExperienceAndItemsCreated(address newExp, address creator);
    event RegistryUpdated(address newRegistry);
    event ERC6551AccountImplementationUpdated(address newImplementation);
    event HatsUpdated(address newHats);

    function testDeployment() public {
        address _characterSheetsImplementation = characterSheetsFactory.characterSheetsImplementation();
        address _experienceAndItemsImplementation = characterSheetsFactory.experienceAndItemsImplementation();
        address _hatsAddress = characterSheetsFactory.hatsAddress();
        address _erc6551Registry = characterSheetsFactory.erc6551Registry();
        address _erc6551AccountImplementation = characterSheetsFactory.erc6551AccountImplementation();

        assertEq(_characterSheetsImplementation, address(characterSheetsImplementation), "wrong character sheets");
        assertEq(_experienceAndItemsImplementation, address(experienceAndItemsImplementation), "wrong experience");
        assertEq(_hatsAddress, address(hats), "wrong hats");
        assertEq(_erc6551Registry, address(erc6551Registry), "wrong registry");
        assertEq(_erc6551AccountImplementation, address(erc6551Implementation),
        "wrong erc6551 account implementation.");
    }

    function testUpdateCharacterSheetsImplementation() public {
        vm.prank(admin);
        vm.expectEmit(true, false, false, false);
        emit CharacterSheetsUpdated(address(1));
        characterSheetsFactory.updateCharacterSheetsImplementation(address(1));
    }

    function testUpdateExperienceAndItemsImplementation() public {
        vm.prank(admin);
        vm.expectEmit(true, false, false, false);
        emit ExperienceUpdated(address(1));
        characterSheetsFactory.updateExperienceAndItemsImplementation(address(1));
    }

    function testUpdateERC6551Registry() public {
        vm.prank(admin);
        vm.expectEmit(false, false, false, false);
        emit RegistryUpdated(address(1));
        characterSheetsFactory.updateERC6551Registry(address(1));
    }

    function testUpdaterERC6551AccountImplementation() public {
        vm.prank(admin);
        vm.expectEmit(false, false, false, false);
        emit ERC6551AccountImplementationUpdated(address(1));
        characterSheetsFactory.updateERC6551AccountImplementation(address(1));
    }

    function testUpdateHats() public {
        vm.prank(admin);
        vm.expectEmit(false, false, false, false);
        emit HatsUpdated(address(1));
        characterSheetsFactory.updateHats(address(1));
    }

    function testCreate() public {
        address[] memory dungeonMasters = new address[](2);
        dungeonMasters[0] = address(1);
        dungeonMasters[1] = address(2);
        //create a bunch of sheets
        for (uint256 i = 0; i < 50; i++) {
            vm.prank(player1);
            vm.expectEmit(true, true, false, false);
            emit CharacterSheetsCreated(address(0), player1);
            (address sheets, address exp) = characterSheetsFactory.create(
                dungeonMasters,
                address(dao),
                player1,
                "new_test_base_uri_experience/",
                "new_test_base_uri_character_sheets/"
            );
            assertEq(address(CharacterSheetsImplementation(sheets).experience()), exp, "wrong experience");
            assertEq(address(ExperienceAndItemsImplementation(exp).characterSheets()), sheets, "wrong sheets");
        }
    }
}
