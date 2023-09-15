// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
pragma abicoder v2;

import "forge-std/Test.sol";
import "./helpers/SetUp.sol";
import "../src/implementations/ItemsImplementation.sol";

// import "forge-std/console2.sol";

contract CharacterSheetsTest is Test, SetUp {
    event CharacterSheetsCreated(address creator, address characterSheets, address classes, address experienceAndItems);
    event CharacterSheetsUpdated(address newCharacterSheets);
    event ExperienceUpdated(address newExperience);
    event ExperienceAndItemsCreated(address newExp, address creator);
    event RegistryUpdated(address newRegistry);
    event ERC6551AccountImplementationUpdated(address newImplementation);
    event ClassesImplementationUpdated(address newClasses);
    event ItemsUpdated(address newItems);

    function testDeployment() public {
        address _characterSheetsImplementation = characterSheetsFactory.characterSheetsImplementation();
        address _itemsImplementation = characterSheetsFactory.itemsImplementation();
        address _classesImplementation = characterSheetsFactory.classesImplementation();
        address _erc6551Registry = characterSheetsFactory.erc6551Registry();
        address _erc6551AccountImplementation = characterSheetsFactory.erc6551AccountImplementation();

        assertEq(
            _characterSheetsImplementation, address(stored.characterSheetsImplementation), "wrong character sheets"
        );
        assertEq(_itemsImplementation, address(stored.experienceImplementation), "wrong experience");
        assertEq(_classesImplementation, address(stored.classesImplementation), "wrong Classes");
        assertEq(_erc6551Registry, address(erc6551Registry), "wrong registry");
        assertEq(_erc6551AccountImplementation, address(erc6551Implementation), "wrong erc6551 account implementation.");
    }

    function testUpdateCharacterSheetsImplementation() public {
        vm.prank(admin);
        vm.expectEmit(true, false, false, false);
        emit CharacterSheetsUpdated(address(1));
        characterSheetsFactory.updateCharacterSheetsImplementation(address(1));
        assertEq(characterSheetsFactory.characterSheetsImplementation(), address(1));
    }

    function testUpdateItemsImplementation() public {
        vm.prank(admin);
        vm.expectEmit(true, false, false, false);
        emit ItemsUpdated(address(1));
        characterSheetsFactory.updateItemsImplementation(address(1));
        assertEq(characterSheetsFactory.itemsImplementation(), address(1));
    }

    function testUpdateERC6551Registry() public {
        vm.prank(admin);
        vm.expectEmit(false, false, false, false);
        emit RegistryUpdated(address(1));
        characterSheetsFactory.updateERC6551Registry(address(1));
        assertEq(characterSheetsFactory.erc6551Registry(), address(1));
    }

    function testUpdaterERC6551AccountImplementation() public {
        vm.prank(admin);
        vm.expectEmit(false, false, false, false);
        emit ERC6551AccountImplementationUpdated(address(1));
        characterSheetsFactory.updateERC6551AccountImplementation(address(1));
        assertEq(characterSheetsFactory.erc6551AccountImplementation(), address(1));
    }

    function testUpdateClassesImplementation() public {
        vm.startPrank(admin);
        vm.expectEmit(false, false, false, false);
        emit ClassesImplementationUpdated(address(1));
        characterSheetsFactory.updateClassesImplementation(address(1));
        vm.stopPrank();

        assertEq(characterSheetsFactory.classesImplementation(), address(1));
    }

    function testCreate() public {
        address[] memory dungeonMasters = new address[](2);
        dungeonMasters[0] = address(1);
        dungeonMasters[1] = address(2);
        //create a bunch of sheets
        for (uint256 i = 0; i < 10; i++) {
            vm.prank(player1);
            vm.expectEmit(true, true, false, false);
            emit CharacterSheetsCreated(player1, address(0), address(0), address(0));
            bytes memory baseUriData = abi.encode(
                "test_metadata_uri_character_sheets/",
                "test_base_uri_character_sheets/",
                "test_base_uri_items/",
                "test_base_uri_classes/"
            );

            (address sheets, address items, address exp, address class) =
                characterSheetsFactory.create(dungeonMasters, address(dao), baseUriData);

            assertEq(address(CharacterSheetsImplementation(sheets).items()), items, "wrong experience");
            assertEq(address(ItemsImplementation(items).characterSheets()), sheets, "wrong sheets");
            assertEq(address(ItemsImplementation(items).classes()), class, "wrong classes");
            // assertEq(exp, address(0), "incorrect address");
            assertEq(
                CharacterSheetsImplementation(sheets).metadataURI(),
                "test_metadata_uri_character_sheets/",
                "Wrong character sheets metadata uri"
            );
            assertEq(
                CharacterSheetsImplementation(sheets).baseTokenURI(),
                "test_base_uri_character_sheets/",
                "Wrong character sheets base uri"
            );
            assertEq(ItemsImplementation(items).getBaseURI(), "test_base_uri_items/", "Wrong exp base uri");
            assertEq(ClassesImplementation(class).getBaseURI(), "test_base_uri_classes/", "Wrong classes base uri");
            assertTrue(
                CharacterSheetsImplementation(sheets).hasRole(keccak256("DUNGEON_MASTER"), address(1)),
                "incorrect dungeon master 1 "
            );
            assertTrue(
                CharacterSheetsImplementation(sheets).hasRole(keccak256("DUNGEON_MASTER"), address(2)),
                "incorrect dungeon master 2 "
            );
            assertEq(
                address(CharacterSheetsImplementation(sheets).erc6551AccountImplementation()),
                address(erc6551Implementation),
                "incorrect 6551 account"
            );
        }
    }
}
