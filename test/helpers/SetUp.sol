// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
pragma abicoder v2;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import {ItemsImplementation} from "../../src/implementations/ItemsImplementation.sol";
import {ExperienceImplementation} from "../../src/implementations/ExperienceImplementation.sol";
import {CharacterSheetsFactory} from "../../src/CharacterSheetsFactory.sol";
import {EligibilityAdaptor} from "../../src/adaptors/EligibilityAdaptor.sol";
import {ClassLevelAdaptor} from "../../src/adaptors/ClassLevelAdaptor.sol";
import {CharacterSheetsImplementation} from "../../src/implementations/CharacterSheetsImplementation.sol";
import {ClassesImplementation} from "../../src/implementations/ClassesImplementation.sol";
import {IMolochDAO} from "../../src/interfaces/IMolochDAO.sol";
import {Moloch} from "../../src/mocks/MockMoloch.sol";

import "../../src/lib/Structs.sol";
import "murky/src/Merkle.sol";
import {ERC6551Registry} from "../../src/mocks/ERC6551Registry.sol";
import {CharacterAccount} from "../../src/CharacterAccount.sol";
import {MultiSend} from "../../src/lib/MultiSend.sol";
import {Category} from "../../src/lib/MultiToken.sol";

// hats imports
import {HatsAdaptor} from "../../src/adaptors/HatsAdaptor.sol";
import {HatsModuleFactory} from "hats-module/HatsModuleFactory.sol";
import {Hats} from "hats-protocol/Hats.sol";
import {AdminHatEligibilityModule} from "../../src/adaptors/hats_modules/AdminHatEligibilityModule.sol";
import {DungeonMasterHatEligibilityModule} from "../../src/adaptors/hats_modules/DungeonMasterHatEligibilityModule.sol";
import {PlayerHatEligibilityModule} from "../../src/adaptors/hats_modules/PlayerHatEligibilityModule.sol";
import {CharacterHatEligibilityModule} from "../../src/adaptors/hats_modules/CharacterHatEligibilityModule.sol";

struct StoredImplementationAddresses {
    address characterSheetsImplementation;
    address experienceImplementation;
    address itemsImplementation;
    address classesImplementation;
    address hatsAdaptorImplementation;
    address adminHatEligibilityModuleImplementation;
    address dungeonMasterHatEligibilityModuleImplementation;
    address playerHatEligibilityModuleImplementation;
    address characterHatEligibilityModuleImplementation;
}

struct StoredCreatedContracts {
    address characterSheets;
    address items;
    address classes;
    address experience;
    address eligibility;
    address classLevels;
    address hatsAdaptor;
}

contract SetUp is Test {
    using stdJson for string;

    CharacterSheetsImplementation public characterSheets;
    ExperienceImplementation public experience;
    ItemsImplementation public items;
    ClassesImplementation public classes;

    CharacterSheetsFactory public characterSheetsFactory;
    EligibilityAdaptor public eligibility;
    ClassLevelAdaptor public classLevels;
    HatsAdaptor public hatsAdaptor;
    HatsModuleFactory public hatsModuleFactory;
    Hats public hats;

    Moloch public dao;

    StoredImplementationAddresses public storedImp;
    StoredCreatedContracts public storedCreated;

    address public admin = address(0xdeadce11);
    address public player1 = address(0xbeef);
    address public player2 = address(0xbabe);
    address public rando = address(0xc0ffee);
    address public npc1;
    uint256 public testClassId;
    uint256 public testItemId;

    Merkle public merkle = new Merkle();

    ERC6551Registry erc6551Registry;
    CharacterAccount erc6551Implementation;
    MultiSend multiSend;

    address[] adminArray;
    address[] dungeonMastersArray;

    function setUp() public {
        vm.startPrank(admin);

        //create mock moloch dao for test
        dao = new Moloch();

        // create eligibilityAdaptor implementation
        eligibility = new EligibilityAdaptor();
        // create class level adaptor implementation
        classLevels = new ClassLevelAdaptor();

        vm.label(address(dao), "Moloch");
        vm.label(address(eligibility), "Eligibility Adaptor");

        characterSheetsFactory = new CharacterSheetsFactory();

        // hats contract deployments
        hats = new Hats("Test Hats", "test_hats_base_img_uri");
        hatsModuleFactory = new HatsModuleFactory(hats, "test hats factory");

        // deploy and store implementation addresses
        storedImp.itemsImplementation = address(new ItemsImplementation());
        storedImp.classesImplementation = address(new ClassesImplementation());
        storedImp.characterSheetsImplementation = address(new CharacterSheetsImplementation());
        storedImp.experienceImplementation = address(new ExperienceImplementation());

        // hats integration
        storedImp.hatsAdaptorImplementation = address(new HatsAdaptor());
        storedImp.adminHatEligibilityModuleImplementation = address(new AdminHatEligibilityModule("v 0.1"));
        storedImp.dungeonMasterHatEligibilityModuleImplementation =
            address(new DungeonMasterHatEligibilityModule("v 0.1"));
        storedImp.playerHatEligibilityModuleImplementation = address(new PlayerHatEligibilityModule("v 0.1"));
        storedImp.characterHatEligibilityModuleImplementation = address(new CharacterHatEligibilityModule("v 0.1"));

        characterSheetsFactory.initialize();

        erc6551Registry = new ERC6551Registry();
        erc6551Implementation = new CharacterAccount();
        multiSend = new MultiSend();

        dao.addMember(player1);
        dao.addMember(admin);

        characterSheetsFactory.updateCharacterSheetsImplementation(address(storedImp.characterSheetsImplementation));
        characterSheetsFactory.updateItemsImplementation(address(storedImp.itemsImplementation));
        characterSheetsFactory.updateClassesImplementation(address(storedImp.classesImplementation));
        characterSheetsFactory.updateExperienceImplementation(address(storedImp.experienceImplementation));
        characterSheetsFactory.updateHatsAdaptorImplementation(address(storedImp.hatsAdaptorImplementation));

        dungeonMastersArray.push(admin);
        adminArray.push(admin);

        characterSheetsFactory.updateERC6551Registry(address(erc6551Registry));
        characterSheetsFactory.updateERC6551AccountImplementation(address(erc6551Implementation));

        bytes memory baseUriData = abi.encode(
            "test_metadata_uri_character_sheets/",
            "test_base_uri_character_sheets/",
            "test_base_uri_items/",
            "test_base_uri_classes/"
        );

        storedCreated.characterSheets = characterSheetsFactory.createCharacterSheets();

        storedCreated.items = characterSheetsFactory.createItems();

        storedCreated.experience = characterSheetsFactory.createExperience();

        storedCreated.classes = characterSheetsFactory.createClasses();

        storedCreated.eligibility = characterSheetsFactory.createEligibilityAdaptor(address(eligibility));

        storedCreated.classLevels = characterSheetsFactory.createClassLevelAdaptor(address(classLevels));

        storedCreated.hatsAdaptor =
            characterSheetsFactory.createHatsAdaptor(address(storedImp.hatsAdaptorImplementation));

        characterSheetsFactory.initializeContracts(
            abi.encode(
                storedCreated.eligibility,
                storedCreated.classLevels,
                storedCreated.hatsAdaptor,
                storedCreated.characterSheets,
                storedCreated.experience,
                storedCreated.items,
                storedCreated.classes
            ),
            baseUriData
        );

        characterSheets = CharacterSheetsImplementation(storedCreated.characterSheets);

        assertEq(address(characterSheets.items()), storedCreated.items, "incorrect items address in setup");

        items = ItemsImplementation(storedCreated.items);

        classes = ClassesImplementation(storedCreated.classes);

        experience = ExperienceImplementation(storedCreated.experience);

        eligibility = EligibilityAdaptor(storedCreated.eligibility);

        classLevels = ClassLevelAdaptor(storedCreated.classLevels);

        hatsAdaptor = HatsAdaptor(storedCreated.hatsAdaptor);

        //initialize created adaptors

        eligibility.initialize(admin, address(dao));

        classLevels.initialize(admin, address(classes), address(experience));

        // initialize hats adaptor
        bytes memory encodedHatsAddresses = abi.encode(
            address(hats),
            address(hatsModuleFactory),
            storedImp.adminHatEligibilityModuleImplementation,
            storedImp.dungeonMasterHatEligibilityModuleImplementation,
            storedImp.playerHatEligibilityModuleImplementation,
            storedImp.characterHatEligibilityModuleImplementation,
            adminArray,
            dungeonMastersArray,
            storedCreated.characterSheets,
            address(erc6551Registry),
            address(erc6551Implementation)
        );

        bytes memory encodedHatsStrings = abi.encode(
            "test_hats_base_img",
            "test tophat description",
            "test_admin_uri",
            "test_admin_description",
            "test_dungeon_uri",
            "test_dungeon_description",
            "test_player_uri",
            "test_player_description",
            "test_character_uri",
            "test_character_description"
        );
        hatsAdaptor.initialize(admin, encodedHatsAddresses, encodedHatsStrings);

        //set registry in character Sheets Contract
        characterSheets.setERC6551Registry(address(erc6551Registry));

        testClassId = classes.createClassType(createNewClass(true));

        testItemId = items.createItemType(createNewItem(false, false, bytes32(0)));
        vm.stopPrank();
        vm.prank(player1);
        uint256 tokenId1 = characterSheets.rollCharacterSheet("test_character_token_uri/");
        assertEq(tokenId1, 0, "incorrect tokenId for player1");
        npc1 = characterSheets.getCharacterSheetByCharacterId(tokenId1).accountAddress;
    }

    function dropExp(address player, uint256 amount) public {
        vm.prank(admin);
        experience.dropExp(player, amount);
    }

    function createNewItemType() public returns (uint256 itemId) {
        bytes memory newItem = createNewItem(false, false, bytes32(0));
        itemId = items.createItemType(newItem);
    }

    function dropItems(address player, uint256 itemId, uint256 amount) public {
        address[] memory players = new address[](1);
        players[0] = player;

        uint256[][] memory itemIds = new uint256[][](1);
        itemIds[0] = new uint256[](1);
        itemIds[0][0] = itemId;

        uint256[][] memory amounts = new uint256[][](1);
        amounts[0] = new uint256[](1);
        amounts[0][0] = amount;

        vm.prank(admin);
        items.dropLoot(players, itemIds, amounts);
    }

    function generateMerkleRootAndProof(
        uint256[] memory itemIds,
        address[] memory claimers,
        uint256[] memory amounts,
        uint256 indexOfProof
    ) public view returns (bytes32[] memory proof, bytes32 root) {
        bytes32[] memory leaves = new bytes32[](itemIds.length);
        for (uint256 i = 0; i < itemIds.length; i++) {
            leaves[i] = keccak256(bytes.concat(keccak256(abi.encodePacked(itemIds[i], claimers[i], amounts[i]))));
        }
        proof = merkle.getProof(leaves, indexOfProof);
        root = merkle.getRoot(leaves);
    }

    function createNewItem(bool craftable, bool soulbound, bytes32 claimable) public view returns (bytes memory) {
        bytes memory requiredAssets;

        {
            uint8[] memory requiredAssetCategories = new uint8[](1);
            requiredAssetCategories[0] = uint8(Category.ERC20);
            address[] memory requiredAssetAddresses = new address[](1);
            requiredAssetAddresses[0] = address(experience);
            uint256[] memory requiredAssetIds = new uint256[](1);
            requiredAssetIds[0] = 0;
            uint256[] memory requiredAssetAmounts = new uint256[](1);
            requiredAssetAmounts[0] = 100;

            requiredAssets =
                abi.encode(requiredAssetCategories, requiredAssetAddresses, requiredAssetIds, requiredAssetAmounts);
        }

        return abi.encode(craftable, soulbound, claimable, 10 ** 18, abi.encodePacked("test_item_cid/"), requiredAssets);
    }

    function createNewClass(bool claimable) public pure returns (bytes memory data) {
        return abi.encode(claimable, "test_class_cid/");
    }
}
