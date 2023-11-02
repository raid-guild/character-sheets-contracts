// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
pragma abicoder v2;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import "../../src/lib/Structs.sol";
import "../../src/lib/Errors.sol";

import {TestStructs} from "./helpers/TestStructs.sol";
import {Accounts} from "./helpers/Accounts.sol";

//fatory
import {CharacterSheetsFactory} from "../../src/CharacterSheetsFactory.sol";
// implementations
import {CharacterSheetsImplementation} from "../../src/implementations/CharacterSheetsImplementation.sol";
import {ItemsImplementation} from "../../src/implementations/ItemsImplementation.sol";
import {ItemsManagerImplementation} from "../../src/implementations/ItemsManagerImplementation.sol";
import {ClassesImplementation} from "../../src/implementations/ClassesImplementation.sol";
import {ExperienceImplementation} from "../../src/implementations/ExperienceImplementation.sol";

//address storage
import {ImplementationAddressStorage} from "../../src/ImplementationAddressStorage.sol";
import {ClonesAddressStorageImplementation} from "../../src/implementations/ClonesAddressStorageImplementation.sol";

//adaptors
import {CharacterEligibilityAdaptorV2} from "../../src/adaptors/CharacterEligibilityAdaptorV2.sol";
import {CharacterEligibilityAdaptorV3} from "../../src/adaptors/CharacterEligibilityAdaptorV3.sol";
import {ICharacterEligibilityAdaptor} from "../../src/interfaces/ICharacterEligibilityAdaptor.sol";
import {ClassLevelAdaptor} from "../../src/adaptors/ClassLevelAdaptor.sol";
import {HatsAdaptor} from "../../src/adaptors/HatsAdaptor.sol";

//erc6551
import {ERC6551Registry} from "../../src/mocks/ERC6551Registry.sol";
import {CharacterAccount} from "../../src/CharacterAccount.sol";

// multi Send
import {MultiSend} from "../../src/lib/MultiSend.sol";
import {Category} from "../../src/lib/MultiToken.sol";

// hats imports
import {HatsModuleFactory} from "hats-module/HatsModuleFactory.sol";
import {Hats} from "hats-protocol/Hats.sol";

// hats eligibility modules
import {AdminHatEligibilityModule} from "../../src/adaptors/hats-modules/AdminHatEligibilityModule.sol";
import {GameMasterHatEligibilityModule} from "../../src/adaptors/hats-modules/GameMasterHatEligibilityModule.sol";
import {PlayerHatEligibilityModule} from "../../src/adaptors/hats-modules/PlayerHatEligibilityModule.sol";
import {CharacterHatEligibilityModule} from "../../src/adaptors/hats-modules/CharacterHatEligibilityModule.sol";

//test and mocks
import {IMolochDAOV2} from "../../src/interfaces/IMolochDAOV2.sol";
import {IMolochDAOV3} from "../../src/interfaces/IMolochDAOV3.sol";
import {Moloch} from "../../src/mocks/MockMoloch.sol";

import {Merkle} from "murky/src/Merkle.sol";

contract SetUp is Test, Accounts, TestStructs {
    DeployedContracts public deployments;
    CharacterSheetsFactory public characterSheetsFactory;
    ImplementationAddressStorage public implementationStorage;

    Implementations public implementations;
    HatsContracts public hatsContracts;
    ERC6551Contracts public erc6551Contracts;

    ClassesData public classData;
    SheetsData public sheetsData;
    ItemsData public itemsData;

    Moloch public dao;
    Merkle public merkle;

    MultiSend public multisend;

    function setUp() public {
        vm.startPrank(accounts.admin);
        _deployImplementations();
        _deployHatsContracts();
        _deployErc6551Contracts();

        implementationStorage = new ImplementationAddressStorage();

        _deployCharacterSheetsFactory();
        _createContracts();
        // set shares token to test dao to experience erc20  cause I'm in a hurry and don't want to make a test erc20
        dao.setSharesToken(address(deployments.experience));

        _initializeContracts(address(deployments.clones), address(dao));
        _activateContracts(address(deployments.clones));
        vm.stopPrank();

        vm.startPrank(accounts.gameMaster);
        //create a claimable class
        classData.classIdClaimable = deployments.classes.createClassType(createNewClass(true));
        // create a non claimable class
        classData.classId = deployments.classes.createClassType(createNewClass(false));
        bytes memory expRequirement = createRequiredAsset(Category.ERC20, address(deployments.experience), 0, 100);
        //create a soulbound item
        itemsData.itemIdSoulbound =
            deployments.items.createItemType(createNewItem(false, true, bytes32(keccak256("null")), 0, expRequirement));
        //create claimable Item
        itemsData.itemIdClaimable =
            deployments.items.createItemType(createNewItem(false, true, bytes32(0), 1, expRequirement));
        // create craftable item
        itemsData.itemIdCraftable =
            deployments.items.createItemType(createNewItem(true, false, bytes32(keccak256("null")), 1, expRequirement));
        //create free item
        itemsData.itemIdFree =
            deployments.items.createItemType(createNewItem(true, false, bytes32(0), 1, createEmptyRequiredAssets()));
        //give exp to dao member
        deployments.experience.dropExp(accounts.player1, 100);
        vm.stopPrank();

        vm.startPrank(accounts.player1);
        //add player to dao
        dao.addMember(accounts.player1);
        // roll characterSheet for player 1
        sheetsData.characterId1 = deployments.characterSheets.rollCharacterSheet("player1_test_uri");

        //store character address
        accounts.character1 =
            deployments.characterSheets.getCharacterSheetByCharacterId(sheetsData.characterId1).accountAddress;
        vm.stopPrank();

        vm.startPrank(accounts.player2);
        //add player to dao
        dao.addMember(accounts.player2);
        // roll characterSheet for player 2
        sheetsData.characterId2 = deployments.characterSheets.rollCharacterSheet("player2_test_uri");

        //store character address
        accounts.character2 =
            deployments.characterSheets.getCharacterSheetByCharacterId(sheetsData.characterId2).accountAddress;
        vm.stopPrank();
    }

    function dropItems(address character, uint256 _itemId, uint256 amount, address itemsContract) public {
        address[] memory characters = new address[](1);
        characters[0] = character;

        uint256[][] memory itemIds = new uint256[][](1);
        itemIds[0] = new uint256[](1);
        itemIds[0][0] = _itemId;

        uint256[][] memory amounts = new uint256[][](1);
        amounts[0] = new uint256[](1);
        amounts[0][0] = amount;

        ItemsImplementation(itemsContract).dropLoot(characters, itemIds, amounts);
    }

    function dropExp(address character, uint256 amount, address experience) public {
        ExperienceImplementation(experience).dropExp(character, amount);
    }

    function generateMerkleRootAndProof(
        uint256[] memory itemIds,
        address[] memory claimers,
        uint256[] memory amounts,
        uint256 indexOfProof
    ) public view returns (bytes32[] memory proof, bytes32 root) {
        bytes32[] memory leaves = new bytes32[](itemIds.length);
        for (uint256 i = 0; i < itemIds.length; i++) {
            uint256 nonce = deployments.items.getClaimNonce(itemIds[i], claimers[i]);
            leaves[i] = keccak256(bytes.concat(keccak256(abi.encode(itemIds[i], claimers[i], nonce, amounts[i]))));
        }
        proof = merkle.getProof(leaves, indexOfProof);
        root = merkle.getRoot(leaves);
    }

    function createNewItem(
        bool craftable,
        bool soulbound,
        bytes32 claimable,
        uint256 distribution,
        bytes memory requiredAssets
    ) public pure returns (bytes memory) {
        return abi.encode(
            craftable, soulbound, claimable, distribution, 10 ** 18, abi.encodePacked("test_item_cid/"), requiredAssets
        );
    }

    function createNewClass(bool claimable) public pure returns (bytes memory data) {
        return abi.encode(claimable, "test_class_cid/");
    }

    function createAddressMemoryArray(uint256 length) public pure returns (address[] memory newArray) {
        newArray = new address[](length);
    }

    function createRequiredAsset(Category category, address assetAddress, uint256 assetId, uint256 amount)
        public
        pure
        returns (bytes memory)
    {
        bytes memory requiredAssets;

        {
            uint8[] memory requiredAssetCategories = new uint8[](1);
            requiredAssetCategories[0] = uint8(category);
            address[] memory requiredAssetAddresses = new address[](1);
            requiredAssetAddresses[0] = address(assetAddress);
            uint256[] memory requiredAssetIds = new uint256[](1);
            requiredAssetIds[0] = assetId;
            uint256[] memory requiredAssetAmounts = new uint256[](1);
            requiredAssetAmounts[0] = amount;

            requiredAssets =
                abi.encode(requiredAssetCategories, requiredAssetAddresses, requiredAssetIds, requiredAssetAmounts);
        }

        return requiredAssets;
    }

    function createEmptyRequiredAssets() public pure returns (bytes memory) {
        bytes memory requiredAssets;

        {
            uint8[] memory requiredAssetCategories = new uint8[](1);

            address[] memory requiredAssetAddresses = new address[](1);

            uint256[] memory requiredAssetIds = new uint256[](1);

            uint256[] memory requiredAssetAmounts = new uint256[](1);

            requiredAssets =
                abi.encode(requiredAssetCategories, requiredAssetAddresses, requiredAssetIds, requiredAssetAmounts);
        }

        return requiredAssets;
    }

    function _activateContracts(address clonesAddress) internal {
        ClonesAddressStorageImplementation internalClones = ClonesAddressStorageImplementation(clonesAddress);

        deployments.characterSheets = CharacterSheetsImplementation(internalClones.characterSheets());
        deployments.experience = ExperienceImplementation(internalClones.experience());
        deployments.items = ItemsImplementation(internalClones.items());
        deployments.itemsManager = ItemsManagerImplementation(internalClones.itemsManager());
        deployments.classes = ClassesImplementation(internalClones.classes());
        deployments.characterEligibility = ICharacterEligibilityAdaptor(internalClones.characterEligibilityAdaptor());
        deployments.classLevels = ClassLevelAdaptor(internalClones.classLevelAdaptor());
        deployments.hatsAdaptor = HatsAdaptor(internalClones.hatsAdaptor());

        vm.label(address(deployments.characterSheets), "Character Sheets Clone");
        vm.label(address(deployments.experience), "Experience Clone");
        vm.label(address(deployments.items), "Items Clone");
        vm.label(address(deployments.itemsManager), "Items Manager Clone");
        vm.label(address(deployments.classes), "Classes Clone");
        vm.label(address(deployments.characterEligibility), "Character Eligibility Adaptor Clone");
        vm.label(address(deployments.classLevels), "Class Levels Adaptor Clone");
        vm.label(address(deployments.hatsAdaptor), "Hats Adaptor Clone");
    }

    function _deployImplementations() internal {
        dao = new Moloch();
        merkle = new Merkle();

        implementations.characterSheets = new CharacterSheetsImplementation();
        implementations.items = new ItemsImplementation();
        implementations.itemsManager = new ItemsManagerImplementation();
        implementations.experience = new ExperienceImplementation();
        implementations.classes = new ClassesImplementation();
        implementations.clonesAddressStorage = new ClonesAddressStorageImplementation();

        implementations.characterEligibilityAdaptorV2 = new CharacterEligibilityAdaptorV2();
        implementations.characterEligibilityAdaptorV3 = new CharacterEligibilityAdaptorV3();
        implementations.classLevelAdaptor = new ClassLevelAdaptor();
        implementations.hatsAdaptor = new HatsAdaptor();
        implementations.adminModule = new AdminHatEligibilityModule("v 0.1");
        implementations.dmModule = new GameMasterHatEligibilityModule("v 0.1");
        implementations.playerModule = new PlayerHatEligibilityModule("v 0.1");
        implementations.characterModule = new CharacterHatEligibilityModule("v 0.1");

        vm.label(address(dao), "Moloch Implementation");
        vm.label(address(merkle), "Merkle Implementation");
        vm.label(address(implementations.characterSheets), "Character Sheets Implementation");
        vm.label(address(implementations.items), "Items Implementation");
        vm.label(address(implementations.itemsManager), "Items Manager Implementation");
        vm.label(address(implementations.experience), "Experience Implementation");
        vm.label(address(implementations.classes), "Classes Implementation");
        vm.label(address(implementations.clonesAddressStorage), "Clones Address Storage Implementation");
        vm.label(
            address(implementations.characterEligibilityAdaptorV2), "Character Eligibility adaptor V2 Implementation"
        );
        vm.label(
            address(implementations.characterEligibilityAdaptorV3), "Character Eligibility adaptor V3 Implementation"
        );
        vm.label(address(implementations.classLevelAdaptor), "Class Level adaptor Implementation");
        vm.label(address(implementations.hatsAdaptor), "Hats adaptor Implementation");
        vm.label(address(implementations.adminModule), "Admin Hats Eligibility adaptor Implementation");
        vm.label(address(implementations.dmModule), "Game Master Hats Eligibility adaptor Implementation");
        vm.label(address(implementations.playerModule), "Player Hats Eligibility adaptor Implementation");
        vm.label(address(implementations.characterModule), "Character Hats Eligibility adaptor Implementation");
    }

    function _deployHatsContracts() internal {
        hatsContracts.hats = new Hats("Test Hats", "test_hats_base_img_uri");
        hatsContracts.hatsModuleFactory = new HatsModuleFactory(hatsContracts.hats, "test hats factory");

        vm.label(address(hatsContracts.hats), "Hats Contract");
        vm.label(address(hatsContracts.hatsModuleFactory), "Hats Module Factory");
    }

    function _deployErc6551Contracts() internal {
        erc6551Contracts.erc6551Registry = new ERC6551Registry();
        erc6551Contracts.erc6551Implementation = new CharacterAccount();

        vm.label(address(erc6551Contracts.erc6551Registry), "ERC6551 Registry");
        vm.label(address(erc6551Contracts.erc6551Implementation), "ERC6551 Character Account Implementation");
    }

    function _deployCharacterSheetsFactory() internal {
        characterSheetsFactory = new CharacterSheetsFactory();
        implementationStorage = new ImplementationAddressStorage();
        multisend = new MultiSend();

        vm.label(address(characterSheetsFactory), "Character Sheets Factory");
        vm.label(address(implementationStorage), "Implementation Address Storage");
        vm.label(address(multisend), "MultiSend");
        EncodedAddresses memory encodedAddresses;

        encodedAddresses.encodedImplementationAddresses = abi.encode(
            implementations.characterSheets,
            implementations.items,
            implementations.classes,
            implementations.experience,
            implementations.clonesAddressStorage,
            implementations.itemsManager,
            address(erc6551Contracts.erc6551Implementation)
        );

        encodedAddresses.encodedModuleAddresses = abi.encode(
            implementations.adminModule,
            implementations.dmModule,
            implementations.playerModule,
            implementations.characterModule
        );

        encodedAddresses.encodedAdaptorAddresses = abi.encode(
            implementations.hatsAdaptor,
            implementations.characterEligibilityAdaptorV2,
            implementations.characterEligibilityAdaptorV3,
            implementations.classLevelAdaptor
        );

        encodedAddresses.encodedExternalAddresses = abi.encode(
            address(erc6551Contracts.erc6551Registry),
            address(hatsContracts.hats),
            address(hatsContracts.hatsModuleFactory)
        );

        implementationStorage.initialize(
            encodedAddresses.encodedImplementationAddresses,
            encodedAddresses.encodedModuleAddresses,
            encodedAddresses.encodedAdaptorAddresses,
            encodedAddresses.encodedExternalAddresses
        );
        characterSheetsFactory.initialize(address(implementationStorage));
    }

    function _createContracts() internal {
        deployments.clones = ClonesAddressStorageImplementation(characterSheetsFactory.create(address(dao)));
    }

    function _initializeContracts(address clonesStorageAddress, address _dao) internal {
        address[] memory adminArray = createAddressMemoryArray(1);
        adminArray[0] = accounts.admin;

        address[] memory gameMastersArray = createAddressMemoryArray(1);
        gameMastersArray[0] = accounts.gameMaster;

        bytes memory encodedHatsAddresses =
            abi.encode(adminArray, gameMastersArray, address(implementationStorage), address(deployments.clones));

        bytes memory encodedHatsStrings = abi.encode(
            "test_hats_base_img",
            "test tophat description",
            "test_admin_uri",
            "test_admin_description",
            "test_game_uri",
            "test_game_description",
            "test_player_uri",
            "test_player_description",
            "test_character_uri",
            "test_character_description"
        );

        bytes memory baseUriData = abi.encode(
            "test_metadata_uri_character_sheets/",
            "test_base_uri_character_sheets/",
            "test_base_uri_items/",
            "test_base_uri_classes/"
        );

        characterSheetsFactory.initializeContracts(
            clonesStorageAddress, _dao, encodedHatsAddresses, encodedHatsStrings, baseUriData
        );
    }
}
