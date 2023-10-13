// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
pragma abicoder v2;

// import "forge-std/Test.sol";
// import "forge-std/console2.sol";
// import {ItemsImplementation} from "../../src/implementations/ItemsImplementation.sol";
// import {ExperienceImplementation} from "../../src/implementations/ExperienceImplementation.sol";
// import {CharacterSheetsFactory} from "../../src/CharacterSheetsFactory.sol";
// import {CharacterEligibilityAdaptor} from "../../src/adaptors/CharacterEligibilityAdaptor.sol";
// import {ClassLevelAdaptor} from "../../src/adaptors/ClassLevelAdaptor.sol";
// import {CharacterSheetsImplementation} from "../../src/implementations/CharacterSheetsImplementation.sol";
// import {ClassesImplementation} from "../../src/implementations/ClassesImplementation.sol";
// import {IMolochDAO} from "../../src/interfaces/IMolochDAO.sol";
// import {Moloch} from "../../src/mocks/MockMoloch.sol";

// import "../../src/lib/Structs.sol";
// import "murky/src/Merkle.sol";
// import {ERC6551Registry} from "../../src/mocks/ERC6551Registry.sol";
// import {CharacterAccount} from "../../src/CharacterAccount.sol";
// import {MultiSend} from "../../src/lib/MultiSend.sol";
// import {Category} from "../../src/lib/MultiToken.sol";

// // hats imports
// import {HatsAdaptor} from "../../src/adaptors/HatsAdaptor.sol";
// import {HatsModuleFactory} from "hats-module/HatsModuleFactory.sol";
// import {Hats} from "hats-protocol/Hats.sol";
// import {AdminHatEligibilityModule} from "../../src/adaptors/hats-modules/AdminHatEligibilityModule.sol";
// import {DungeonMasterHatEligibilityModule} from "../../src/adaptors/hats-modules/DungeonMasterHatEligibilityModule.sol";
// import {PlayerHatEligibilityModule} from "../../src/adaptors/hats-modules/PlayerHatEligibilityModule.sol";
// import {CharacterHatEligibilityModule} from "../../src/adaptors/hats-modules/CharacterHatEligibilityModule.sol";
// import {ItemsManagerImplementation} from "../../src/implementations/ItemsManagerImplementation.sol";

// import {ImplementationAddressStorage} from "../../src/lib/ImplementationAddressStorage.sol";
// import {ClonesAddressStorage} from "../../src/lib/ClonesAddressStorage.sol";

// struct StoredImplementationAddresses {
//     address characterSheetsImplementation;
//     address experienceImplementation;
//     address itemsImplementation;
//     address classesImplementation;
//     address hatsAdaptorImplementation;
//     address adminHatsEligibilityModuleImplementation;
//     address dungeonMasterHatsEligibilityModuleImplementation;
//     address playerHatsEligibilityModuleImplementation;
//     address characterHatsEligibilityModuleImplementation;
//     address itemsManagerImplementation;
//     address clonesAddressStorageImplementation;
//     address CharacterEligibilityAdaptorImplementation;
//     address classLevelAdaptorImplementation;
// }

// struct StoredCreatedContracts {
//     address characterSheets;
//     address items;
//     address classes;
//     address experience;
//     address eligibility;
//     address classLevels;
//     address hatsAdaptor;
//     address itemsManager;
// }

// struct ContractsStruct {
//     CharacterSheetsImplementation characterSheets;
//     ExperienceImplementation experience;
//     ItemsImplementation items;
//     ClassesImplementation classes;
//     CharacterSheetsFactory characterSheetsFactory;
//     CharacterEligibilityAdaptor eligibility;
//     ClassLevelAdaptor classLevels;
//     HatsAdaptor hatsAdaptor;
//     HatsModuleFactory hatsModuleFactory;
//     Hats hats;
//     ItemsManagerImplementation itemsManager;
//     ClonesAddressStorage clones;
//     ImplementationAddressStorage implementationsStorage;
//     Moloch dao;
//     Merkle merkle;
// }

// contract SetUp1 is Test {
//     using stdJson for string;

//     ContractsStruct public contracts;

//     StoredImplementationAddresses public storedImp;
//     StoredCreatedContracts public storedCreated;

//     address public admin = address(0xdeadce11);
//     address public player1 = address(0xbeef);
//     address public player2 = address(0xbabe);
//     address public rando = address(0xc0ffee);
//     address public npc1;
//     uint256 public classId;
//     uint256 public itemId;

//     ERC6551Registry public erc6551Registry;
//     CharacterAccount public erc6551Implementation;
//     MultiSend public multiSend;

//     address[] public adminArray;
//     address[] public dungeonMastersArray;

//     function setUp() public {
//         vm.startPrank(admin);

//         //create mock moloch dao for test
//         contracts.dao = new Moloch();
//         contracts.merkle = new Merkle();
//         // create CharacterEligibilityAdaptor implementation
//         contracts.eligibility = new CharacterEligibilityAdaptor();
//         // create class level adaptor implementation
//         contracts.classLevels = new ClassLevelAdaptor();

//         erc6551Registry = new ERC6551Registry();
//         erc6551Implementation = new CharacterAccount();
//         multiSend = new MultiSend();

//         vm.label(address(contracts.dao), "Moloch");
//         vm.label(address(contracts.eligibility), "Eligibility Adaptor");

//         contracts.characterSheetsFactory = new CharacterSheetsFactory();

//         // hats contract deployments
//         contracts.hats = new Hats("Test Hats", "test_hats_base_img_uri");

//         contracts.hatsModuleFactory = new HatsModuleFactory(contracts.hats, "test hats factory");

//         // deploy and store implementation addresses
//         contracts.implementationsStorage = ImplementationAddressStorage(new ImplementationAddressStorage());
//         storedImp.itemsImplementation = address(new ItemsImplementation());
//         storedImp.classesImplementation = address(new ClassesImplementation());
//         storedImp.characterSheetsImplementation = address(new CharacterSheetsImplementation());
//         storedImp.experienceImplementation = address(new ExperienceImplementation());
//         storedImp.itemsManagerImplementation = address(new ItemsManagerImplementation());

//         // hats integration
//         storedImp.hatsAdaptorImplementation = address(new HatsAdaptor());
//         storedImp.adminHatsEligibilityModuleImplementation = address(new AdminHatEligibilityModule("v 0.1"));
//         storedImp.dungeonMasterHatsEligibilityModuleImplementation =
//             address(new DungeonMasterHatEligibilityModule("v 0.1"));
//         storedImp.playerHatsEligibilityModuleImplementation = address(new PlayerHatEligibilityModule("v 0.1"));
//         storedImp.characterHatsEligibilityModuleImplementation = address(new CharacterHatEligibilityModule("v 0.1"));
//         storedImp.clonesAddressStorageImplementation = address(new ClonesAddressStorage());
//         storedImp.classLevelAdaptorImplementation = address(contracts.classLevels);
//         storedImp.CharacterEligibilityAdaptorImplementation = address(contracts.eligibility);
//         // initialize implementationsStorage
//         bytes memory encodedImplementations = abi.encode(
//             storedImp.characterSheetsImplementation,
//             storedImp.itemsImplementation,
//             storedImp.classesImplementation,
//             address(erc6551Registry),
//             address(erc6551Implementation),
//             storedImp.experienceImplementation,
//             storedImp.CharacterEligibilityAdaptorImplementation,
//             storedImp.classLevelAdaptorImplementation,
//             storedImp.itemsManagerImplementation,
//             storedImp.hatsAdaptorImplementation,
//             storedImp.clonesAddressStorageImplementation,
//             //hats addresses
//             address(contracts.hats),
//             address(contracts.hatsModuleFactory),
//             //eligibility modules
//             storedImp.adminHatsEligibilityModuleImplementation,
//             storedImp.dungeonMasterHatsEligibilityModuleImplementation,
//             storedImp.playerHatsEligibilityModuleImplementation,
//             storedImp.characterHatsEligibilityModuleImplementation
//         );
//         contracts.implementationsStorage.initialize(encodedImplementations);
//         contracts.characterSheetsFactory.initialize(address(contracts.implementationsStorage));

//         contracts.dao.addMember(player1);
//         contracts.dao.addMember(admin);

//         dungeonMastersArray.push(admin);
//         adminArray.push(admin);

//         bytes memory baseUriData = abi.encode(
//             "test_metadata_uri_character_sheets/",
//             "test_base_uri_character_sheets/",
//             "test_base_uri_items/",
//             "test_base_uri_classes/"
//         );

//         storedCreated.characterSheets = contracts.characterSheetsFactory.createCharacterSheets();

//         storedCreated.items = contracts.characterSheetsFactory.createItems();

//         storedCreated.experience = contracts.characterSheetsFactory.createExperience();

//         storedCreated.classes = contracts.characterSheetsFactory.createClasses();

//         storedCreated.eligibility =
//             contracts.characterSheetsFactory.createCharacterEligibilityAdaptor(address(contracts.eligibility));

//         storedCreated.classLevels =
//             contracts.characterSheetsFactory.createClassLevelAdaptor(address(contracts.classLevels));

//         storedCreated.itemsManager = contracts.characterSheetsFactory.createItemsManager();

//         storedCreated.hatsAdaptor =
//             contracts.characterSheetsFactory.createHatsAdaptor(address(storedImp.hatsAdaptorImplementation));
//         contracts.clones = ClonesAddressStorage(contracts.characterSheetsFactory.createClonesStorage());

//         contracts.characterSheetsFactory.initializeContracts(
//             address(contracts.clones),
//             abi.encode(
//                 storedCreated.characterSheets,
//                 storedCreated.items,
//                 storedCreated.itemsManager,
//                 storedCreated.classes,
//                 storedCreated.experience,
//                 storedCreated.eligibility,
//                 storedCreated.classLevels,
//                 storedCreated.hatsAdaptor
//             ),
//             baseUriData
//         );

//         contracts.characterSheets = CharacterSheetsImplementation(storedCreated.characterSheets);

//         assertEq(address(contracts.characterSheets.items()), storedCreated.items, "incorrect items address in setup");

//         contracts.items = ItemsImplementation(storedCreated.items);

//         contracts.classes = ClassesImplementation(storedCreated.classes);

//         contracts.experience = ExperienceImplementation(storedCreated.experience);

//         contracts.eligibility = CharacterEligibilityAdaptor(storedCreated.eligibility);

//         contracts.classLevels = ClassLevelAdaptor(storedCreated.classLevels);

//         contracts.hatsAdaptor = HatsAdaptor(storedCreated.hatsAdaptor);

//         contracts.itemsManager = ItemsManagerImplementation(storedCreated.itemsManager);

//         //initialize created adaptors

//         // eligibility.initialize(admin, address(contracts.dao));

//         // classLevels.initialize(admin, address(contracts.classes), address(contracts.experience));

//         // initialize hats adaptor
//         // bytes memory encodedHatsAddresses = abi.encode(
//         //     address(contracts.hats),
//         //     address(contracts.hatsModuleFactory),
//         //     storedImp.adminHatEligibilityModuleImplementation,
//         //     storedImp.dungeonMasterHatEligibilityModuleImplementation,
//         //     storedImp.playerHatEligibilityModuleImplementation,
//         //     storedImp.characterHatEligibilityModuleImplementation,
//         //     adminArray,
//         //     dungeonMastersArray,
//         //     storedCreated.characterSheets,
//         //     address(erc6551Registry),
//         //     address(erc6551Implementation)
//         // );
//         bytes memory encodedHatsAddresses =
//             abi.encode(adminArray, dungeonMastersArray, address(contracts.implementationsStorage));

//         bytes memory encodedHatsStrings = abi.encode(
//             "test_hats_base_img",
//             "test tophat description",
//             "test_admin_uri",
//             "test_admin_description",
//             "test_dungeon_uri",
//             "test_dungeon_description",
//             "test_player_uri",
//             "test_player_description",
//             "test_character_uri",
//             "test_character_description"
//         );
//         contracts.hatsAdaptor.initialize(admin, encodedHatsAddresses, encodedHatsStrings);

//         //set registry in character Sheets Contract
//         // characterSheets.setERC6551Registry(address(erc6551Registry));

//         classId = contracts.classes.createClassType(createNewClass(true));

//         itemId = contracts.items.createItemType(createNewItem(false, false, bytes32(0)));
//         vm.stopPrank();
//         vm.prank(player1);
//         uint256 tokenId1 = contracts.characterSheets.rollCharacterSheet("test_character_token_uri/");
//         assertEq(tokenId1, 0, "incorrect tokenId for player1");
//         npc1 = contracts.characterSheets.getCharacterSheetByCharacterId(tokenId1).accountAddress;
//     }

//     function dropExp(address player, uint256 amount) public {
//         vm.prank(admin);
//         contracts.experience.dropExp(player, amount);
//     }

//     function createNewItemType(bool craftable, bool soulbound) public returns (uint256 _itemId) {
//         bytes memory newItem = createNewItem(craftable, soulbound, bytes32(0));
//         _itemId = contracts.items.createItemType(newItem);
//     }

//     function dropItems(address player, uint256 _itemId, uint256 amount) public {
//         address[] memory players = new address[](1);
//         players[0] = player;

//         uint256[][] memory itemIds = new uint256[][](1);
//         itemIds[0] = new uint256[](1);
//         itemIds[0][0] = _itemId;

//         uint256[][] memory amounts = new uint256[][](1);
//         amounts[0] = new uint256[](1);
//         amounts[0][0] = amount;

//         vm.prank(admin);
//         contracts.items.dropLoot(players, itemIds, amounts);
//     }

//     function generateMerkleRootAndProof(
//         uint256[] memory itemIds,
//         address[] memory claimers,
//         uint256[] memory amounts,
//         uint256 indexOfProof
//     ) public view returns (bytes32[] memory proof, bytes32 root) {
//         bytes32[] memory leaves = new bytes32[](itemIds.length);
//         for (uint256 i = 0; i < itemIds.length; i++) {
//             leaves[i] = keccak256(bytes.concat(keccak256(abi.encodePacked(itemIds[i], claimers[i], amounts[i]))));
//         }
//         proof = contracts.merkle.getProof(leaves, indexOfProof);
//         root = contracts.merkle.getRoot(leaves);
//     }

//     function createNewItem(bool craftable, bool soulbound, bytes32 claimable) public view returns (bytes memory) {
//         bytes memory requiredAssets;

//         {
//             uint8[] memory requiredAssetCategories = new uint8[](1);
//             requiredAssetCategories[0] = uint8(Category.ERC20);
//             address[] memory requiredAssetAddresses = new address[](1);
//             requiredAssetAddresses[0] = address(contracts.experience);
//             uint256[] memory requiredAssetIds = new uint256[](1);
//             requiredAssetIds[0] = 0;
//             uint256[] memory requiredAssetAmounts = new uint256[](1);
//             requiredAssetAmounts[0] = 100;

//             requiredAssets =
//                 abi.encode(requiredAssetCategories, requiredAssetAddresses, requiredAssetIds, requiredAssetAmounts);
//         }

//         return abi.encode(craftable, soulbound, claimable, 10 ** 18, abi.encodePacked("test_item_cid/"), requiredAssets);
//     }

//     function createNewItemWithoutRequirements(bool craftable, bool soulbound, bytes32 claimable)
//         public
//         pure
//         returns (bytes memory)
//     {
//         bytes memory requiredAssets;

//         {
//             uint8[] memory requiredAssetCategories = new uint8[](0);
//             address[] memory requiredAssetAddresses = new address[](0);
//             uint256[] memory requiredAssetIds = new uint256[](0);
//             uint256[] memory requiredAssetAmounts = new uint256[](0);

//             requiredAssets =
//                 abi.encode(requiredAssetCategories, requiredAssetAddresses, requiredAssetIds, requiredAssetAmounts);
//         }

//         return abi.encode(craftable, soulbound, claimable, 10 ** 18, abi.encodePacked("test_item_cid/"), requiredAssets);
//     }

//     function createNewClass(bool claimable) public pure returns (bytes memory data) {
//         return abi.encode(claimable, "test_class_cid/");
//     }
// }
