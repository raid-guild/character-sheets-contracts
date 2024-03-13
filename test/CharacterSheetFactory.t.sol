// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
pragma abicoder v2;

import "forge-std/Test.sol";

import "./setup/SetUp.t.sol";

// import "forge-std/console2.sol";

contract CharacterSheetsFactoryTest is Test, SetUp {
    struct EncodedHatsData {
        bytes encodedHatsAddresses;
        bytes encodedHatsStrings;
    }

    struct EncodedClonesInitData {
        bytes encodedCloneAddresses;
        bytes encodedAdaptorAddresses;
    }

    event NewGameStarted(address creator, address clonesAddressStorage);
    event ImplementationAddressStorageUpdated(address newImplementationAddressStorage);
    event ExperienceCreated(address experienceClone);
    event CharacterSheetsCreated(address expectedCharacterSheets);
    event ItemsCreated(address newItems);
    event ClassesCreated(address expectedClasses);
    event CharacterEligibilityAdaptorCreated(address expectedCharacterEligibilityAdaptor);
    event ClassLevelAdaptorCreated(address expectedClassLevelAdaptor);

    // HAPPY PATH

    function testDeployment() public {
        address _implementationStorage = address(characterSheetsFactory.implementations());

        assertEq(_implementationStorage, address(implementationStorage), "wrong implementations");
    }

    function testUpdateImplementationAddressStorage() public {
        vm.prank(accounts.admin);
        vm.expectEmit(true, false, false, false);
        emit ImplementationAddressStorageUpdated(address(1));
        characterSheetsFactory.updateImplementationAddressStorage(address(1));
        assertEq(address(characterSheetsFactory.implementations()), address(1));
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

    function testCreateItems() public {
        address expectedItems = 0xD9Ce15d0e3c74B4bc3FC19c15114fc34F95c0Df3;
        vm.startPrank(accounts.player1);
        vm.expectEmit(true, false, false, false);
        emit ItemsCreated(expectedItems);
        address newItems = characterSheetsFactory.createItems();
        assertTrue((newItems != address(deployments.items)), "new items not deployed");
    }

    function testCreateClasses() public {
        address expectedClasses = 0xD9Ce15d0e3c74B4bc3FC19c15114fc34F95c0Df3;
        vm.startPrank(accounts.player1);
        vm.expectEmit(true, false, false, false);
        emit ClassesCreated(expectedClasses);
        address newClasses = characterSheetsFactory.createClasses();
        assertTrue((newClasses != address(deployments.classes)), "new classes not deployed");
    }

    function testCreateCharacterEligibilityAdaptor() public {
        address expectedCharacterEligibilityAdaptor = 0xD9Ce15d0e3c74B4bc3FC19c15114fc34F95c0Df3;
        vm.startPrank(accounts.player1);
        vm.expectEmit(true, false, false, false);
        emit CharacterEligibilityAdaptorCreated(expectedCharacterEligibilityAdaptor);
        address newCharacterEligibilityAdaptor = characterSheetsFactory.createCharacterEligibilityAdaptor(
            implementationStorage.molochV2EligibilityAdaptorImplementation()
        );
        assertTrue(
            (newCharacterEligibilityAdaptor != address(deployments.characterEligibility)),
            "new character eligibility adaptor not deployed"
        );
    }

    function testCreateClassLevelAdaptor() public {
        address expectedClassLevelAdaptor = 0xD9Ce15d0e3c74B4bc3FC19c15114fc34F95c0Df3;
        vm.startPrank(accounts.player1);
        vm.expectEmit(true, false, false, false);
        emit ClassLevelAdaptorCreated(expectedClassLevelAdaptor);
        address newClassLevelAdaptor = characterSheetsFactory.createClassLevelAdaptor();
        assertTrue((newClassLevelAdaptor != address(deployments.classLevels)), "new class level adaptor not deployed");
    }

    function testInitializeContracts() public {
        vm.startPrank(accounts.player1);

        DeployedContracts memory newContracts;

        newContracts.characterSheets = CharacterSheetsImplementation(characterSheetsFactory.createCharacterSheets());

        newContracts.items = ItemsImplementation(characterSheetsFactory.createItems());

        newContracts.experience = ExperienceImplementation(characterSheetsFactory.createExperience());

        newContracts.classes = ClassesImplementation(characterSheetsFactory.createClasses());

        newContracts.clones = ClonesAddressStorageImplementation(characterSheetsFactory.createClonesStorage());

        newContracts.characterEligibility = ICharacterEligibilityAdaptor(
            characterSheetsFactory.createCharacterEligibilityAdaptor(address(adaptors.molochV2EligibilityAdaptor))
        );

        newContracts.classLevels =
            ClassLevelAdaptor(characterSheetsFactory.createClassLevelAdaptor(address(adaptors.classLevelAdaptor)));

        newContracts.itemsManager = ItemsManagerImplementation(characterSheetsFactory.createItemsManager());

        newContracts.hatsAdaptor = HatsAdaptor(characterSheetsFactory.createHatsAdaptor(address(adaptors.hatsAdaptor)));

        address[] memory adminArray = createAddressMemoryArray(1);
        adminArray[0] = accounts.admin;

        address[] memory gameMastersArray = createAddressMemoryArray(1);
        gameMastersArray[0] = accounts.gameMaster;

        //STACC TOOO DAMN DANK!
        EncodedClonesInitData memory clonesData;
        EncodedHatsData memory hatsData;

        hatsData.encodedHatsAddresses =
            abi.encode(adminArray, gameMastersArray, address(implementationStorage), address(newContracts.clones));

        hatsData.encodedHatsStrings = abi.encode(
            "new_new_test_hats_base_img",
            "new_test tophat description",
            "new_test_admin_uri",
            "new_test_admin_description",
            "new_test_game_uri",
            "new_test_game_description",
            "new_test_player_uri",
            "new_test_player_description",
            "new_test_character_uri",
            "new_test_character_description"
        );

        bytes memory characterSheetsData = abi.encode(
            address(newContracts.clones),
            address(implementationStorage),
            "new_test_metadata_uri_character_sheets/",
            "new_test_base_uri_character_sheets/"
        );

        clonesData.encodedCloneAddresses = abi.encode(
            address(newContracts.characterSheets),
            address(newContracts.items),
            address(newContracts.itemsManager),
            address(newContracts.classes),
            address(newContracts.experience)
        );

        clonesData.encodedAdaptorAddresses = abi.encode(
            address(newContracts.characterEligibility),
            address(newContracts.classLevels),
            address(newContracts.hatsAdaptor)
        );

        // initialize clones address storage contract
        newContracts.clones.initialize(clonesData.encodedCloneAddresses, clonesData.encodedAdaptorAddresses);

        bytes memory customModuleAddresses = abi.encode(address(0), address(0), address(0), address(0));

        newContracts.characterSheets.initialize(characterSheetsData);
        newContracts.characterEligibility.initialize(accounts.player1, address(dao));
        newContracts.classLevels.initialize(address(newContracts.clones));
        newContracts.hatsAdaptor.initialize(
            accounts.player1, hatsData.encodedHatsAddresses, hatsData.encodedHatsStrings, customModuleAddresses
        );

        bytes memory encodedItemsData = abi.encode(address(newContracts.clones), "new_test_base_uri_items/");
        newContracts.items.initialize(encodedItemsData);
        bytes memory encodedClassesData = abi.encode(address(newContracts.clones), "new_test_base_uri_classes/");
        newContracts.classes.initialize(encodedClassesData);
        newContracts.itemsManager.initialize(address(newContracts.clones));
        newContracts.experience.initialize(address(newContracts.clones));

        assertEq(newContracts.items.getBaseURI(), "new_test_base_uri_items/", "new_incorrect items base uri");
        assertEq(newContracts.classes.getBaseURI(), "new_test_base_uri_classes/", "new_incorrect classes baseUri");
        assertEq(
            newContracts.characterSheets.baseTokenURI(),
            "new_test_base_uri_character_sheets/",
            "new_incorrect sheets base uri"
        );
        assertEq(newContracts.experience.name(), "Experience", "incorrect experience name");
        assertEq(newContracts.characterEligibility.dao(), address(dao), "Character elgibility not initialized");
        assertEq(newContracts.classLevels.getExpForLevel(2), 900, "Character level adaptor not initialized");
    }

    /// UNHAPPY PATH
    //TODO do unhappy path

    function testDeploymentRevert() public {
        //should revert because already initialized
        vm.expectRevert();
        characterSheetsFactory.initialize(address(1));

        address _implementationStorage = address(characterSheetsFactory.implementations());
        assertEq(_implementationStorage, address(implementationStorage), "wrong implementations");
    }

    function testCreateAndInitialize() public {
        bytes memory encodedHatsStrings = abi.encode(
            "new_new_test_hats_base_img",
            "new_test tophat description",
            "new_test_admin_uri",
            "new_test_admin_description",
            "new_test_game_uri",
            "new_test_game_description",
            "new_test_player_uri",
            "new_test_player_description",
            "new_test_character_uri",
            "new_test_character_description"
        );

        bytes memory encodedSheetsStrings = abi.encode(
            "new_test_metadata_uri_character_sheets/",
            "new_test_base_uri_character_sheets/",
            "new_test_base_uri_items/",
            "new_test_base_uri_classes/"
        );

        address[] memory adminArray = createAddressMemoryArray(1);
        adminArray[0] = accounts.admin;

        address[] memory gameMastersArray = createAddressMemoryArray(1);
        gameMastersArray[0] = accounts.gameMaster;

        vm.prank(accounts.player2);
        address newClonesStorage = characterSheetsFactory.createAndInitialize(
            address(dao), adminArray, gameMastersArray, encodedHatsStrings, encodedSheetsStrings
        );
        ClonesAddressStorageImplementation newClones = ClonesAddressStorageImplementation(newClonesStorage);
        CharacterSheetsImplementation newSheets = CharacterSheetsImplementation(newClones.characterSheets());
        HatsAdaptor newHatsAdaptor = HatsAdaptor(newClones.hatsAdaptor());
        assert(newClones.hatsAdaptor() != address(0));
        assertEq(newSheets.baseTokenURI(), "new_test_base_uri_character_sheets/", "wrong sheets uri");
        assertEq(newSheets.metadataURI(), "new_test_metadata_uri_character_sheets/", "wrong sheets metadata uri");
        assertEq(newHatsAdaptor.isAdmin(accounts.admin), true, "admin not admin");
    }

    function testCreateAndInitializeWithZeroDao() public {
        bytes memory encodedHatsStrings = abi.encode(
            "new_new_test_hats_base_img",
            "new_test tophat description",
            "new_test_admin_uri",
            "new_test_admin_description",
            "new_test_game_uri",
            "new_test_game_description",
            "new_test_player_uri",
            "new_test_player_description",
            "new_test_character_uri",
            "new_test_character_description"
        );

        bytes memory encodedSheetsStrings = abi.encode(
            "new_test_metadata_uri_character_sheets/",
            "new_test_base_uri_character_sheets/",
            "new_test_base_uri_items/",
            "new_test_base_uri_classes/"
        );

        address[] memory adminArray = createAddressMemoryArray(1);
        adminArray[0] = accounts.admin;

        address[] memory gameMastersArray = createAddressMemoryArray(1);
        gameMastersArray[0] = accounts.gameMaster;

        vm.prank(accounts.player2);
        address newClonesStorage = characterSheetsFactory.createAndInitialize(
            address(0), adminArray, gameMastersArray, encodedHatsStrings, encodedSheetsStrings
        );
        ClonesAddressStorageImplementation newClones = ClonesAddressStorageImplementation(newClonesStorage);
        CharacterSheetsImplementation newSheets = CharacterSheetsImplementation(newClones.characterSheets());
        HatsAdaptor newHatsAdaptor = HatsAdaptor(newClones.hatsAdaptor());
        assert(newClones.hatsAdaptor() != address(0));
        assertEq(newSheets.baseTokenURI(), "new_test_base_uri_character_sheets/", "wrong sheets uri");
        assertEq(newSheets.metadataURI(), "new_test_metadata_uri_character_sheets/", "wrong sheets metadata uri");
        assertEq(newHatsAdaptor.isAdmin(accounts.admin), true, "admin not admin");
    }
}
