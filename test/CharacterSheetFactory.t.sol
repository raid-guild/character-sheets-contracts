// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
pragma abicoder v2;

import "forge-std/Test.sol";

import "./setup/SetUp.sol";

// import "forge-std/console2.sol";

contract CharacterSheetsTest is Test, SetUp {
    event NewGameStarted(address creator, address clonesAddressStorage);
    event ImplementationAddressStorageUpdated(address newImplementationAddressStorage);
    event ExperienceCreated(address experienceClone);
    event CharacterSheetsCreated(address expectedCharacterSheets);
    // HAPPY PATH

    function testDeployment() public {
        address _implementationStorage = characterSheetsFactory.getImplementationsAddressStorageAddress();

        assertEq(_implementationStorage, address(implementationStorage), "wrong implementations");
    }

    function testUpdateImplementationAddressStorage() public {
        vm.prank(accounts.admin);
        vm.expectEmit(true, false, false, false);
        emit ImplementationAddressStorageUpdated(address(1));
        characterSheetsFactory.updateImplementationAddressStorage(address(1));
        assertEq(characterSheetsFactory.getImplementationsAddressStorageAddress(), address(1));
    }

    // UNHAPPY PATH
    function testDeploymentRevert() public {
        //should revert because already initialized
        vm.expectRevert();
        characterSheetsFactory.initialize(address(1));

        address _implementationStorage = characterSheetsFactory.getImplementationsAddressStorageAddress();
        assertEq(_implementationStorage, address(implementationStorage), "wrong implementations");
    }

    function testCreateExperience() public {
        address expectedExperience = 0xD9Ce15d0e3c74B4bc3FC19c15114fc34F95c0Df3;
        vm.startPrank(accounts.player1);
        vm.expectEmit(true, false, false, false);
        emit ExperienceCreated(expectedExperience);
        address experienceAddress = characterSheetsFactory.createExperience();
        vm.stopPrank();

        assertTrue((experienceAddress == expectedExperience), "invalid Experience");
    }

    function testCreateCharacterSheets() public {
        address expectedCharacterSheets = 0xD9Ce15d0e3c74B4bc3FC19c15114fc34F95c0Df3;
        vm.startPrank(accounts.player1);
        vm.expectEmit(true, false, false, false);
        emit CharacterSheetsCreated(expectedCharacterSheets);
        address characterSheetsAddress = characterSheetsFactory.createCharacterSheets();
        vm.stopPrank();

        assertTrue((characterSheetsAddress == expectedCharacterSheets), "invalid CharacterSheets");
    }

    // function testCreateItems() public {
    //     vm.prank(player1);
    //     address newItems = characterSheetsFactory.createItems();
    //     assert(newItems != address(items));
    // }

    // function testCreateClasses() public {
    //     vm.prank(player1);
    //     address newClasses = characterSheetsFactory.createClasses();
    //     assert(newClasses != address(classes));
    // }

    // function testCreateCharacterEligibilityAdaptor() public {
    //     vm.prank(player1);
    //     address newEligibility = characterSheetsFactory.createCharacterEligibilityAdaptor(address(eligibility));
    //     assert(newEligibility != address(eligibility));
    // }

    // function testCreateClassLevelAdaptor() public {
    //     vm.prank(player1);
    //     address newClassLevel = characterSheetsFactory.createClassLevelAdaptor(address(classLevels));
    //     assert(newClassLevel != address(classLevels));
    // }

    // function testInitializeContracts() public {
    //     vm.startPrank(player1);

    //     address newSheets = characterSheetsFactory.createCharacterSheets();

    //     address newItems = characterSheetsFactory.createItems();

    //     address newExperience = characterSheetsFactory.createExperience();

    //     address newClasses = characterSheetsFactory.createClasses();

    //     address newEligibility = characterSheetsFactory.createCharacterEligibilityAdaptor(address(eligibility));

    //     address newClassLevel = characterSheetsFactory.createClassLevelAdaptor(address(classLevels));

    //     address newItemsManager = characterSheetsFactory.createItemsManager();

    //     address newHatsAdaptor = characterSheetsFactory.createHatsAdaptor(address(storedImp.hatsAdaptorImplementation));
    //     address newClones = characterSheetsFactory.createClonesStorage();

    //     address[] memory dungeonMasters = new address[](1);
    //     dungeonMasters[0] = player1;
    //     bytes memory encodedInitData = abi.encode(
    //         newEligibility,
    //         newClassLevel,
    //         dungeonMasters,
    //         newSheets,
    //         newExperience,
    //         newItems,
    //         newItemsManager,
    //         newClasses
    //     );

    //     bytes memory stringData = abi.encode(
    //         "test_metadata_uri_character_sheets/",
    //         "test_base_uri_character_sheets/",
    //         "test_base_uri_items/",
    //         "test_base_uri_classes/"
    //     );
    //     characterSheetsFactory.initializeContracts(address(newClones), encodedInitData, stringData);

    //     assertEq(ItemsImplementation(newItems).getBaseURI(), "test_base_uri_items/", "incorrect items base uri");
    //     assertEq(ClassesImplementation(newClasses).getBaseURI(), "test_base_uri_classes/", "incorrect classes baseUri");
    //     assertEq(
    //         CharacterSheetsImplementation(newSheets).baseTokenURI(),
    //         "test_base_uri_character_sheets/",
    //         "incorrect sheets base uri"
    //     );
    //     assertEq(ExperienceImplementation(newExperience).name(), "Experience", "incorrect experience name");
    // }
}
