// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
pragma abicoder v2;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import "../../src/lib/Structs.sol";
import "../../src/lib/Errors.sol";

import {TestStructs} from "./helpers/TestStructs.t.sol";
import {Accounts} from "./helpers/Accounts.t.sol";

//fatory
import {CharacterSheetsFactory} from "../../src/CharacterSheetsFactory.sol";
// implementations
import {CharacterSheetsImplementation} from "../../src/implementations/CharacterSheetsImplementation.sol";
import {ItemsImplementation} from "../../src/implementations/ItemsImplementation.sol";
import {
    ItemsManagerImplementation,
    CraftItem,
    RequirementNode,
    RequirementsTree
} from "../../src/implementations/ItemsManagerImplementation.sol";
import {ClassesImplementation} from "../../src/implementations/ClassesImplementation.sol";
import {ExperienceImplementation} from "../../src/implementations/ExperienceImplementation.sol";

//address storage
import {ImplementationAddressStorage} from "../../src/ImplementationAddressStorage.sol";
import {ClonesAddressStorageImplementation} from "../../src/implementations/ClonesAddressStorageImplementation.sol";

//adaptors
import {MolochV2EligibilityAdaptor} from "../../src/adaptors/MolochV2EligibilityAdaptor.sol";
import {MolochV3EligibilityAdaptor} from "../../src/adaptors/MolochV3EligibilityAdaptor.sol";
import {ICharacterEligibilityAdaptor} from "../../src/interfaces/ICharacterEligibilityAdaptor.sol";
import {ClassLevelAdaptor} from "../../src/adaptors/ClassLevelAdaptor.sol";
import {HatsAdaptor} from "../../src/adaptors/HatsAdaptor.sol";

//erc6551
import {ERC6551Registry} from "../../src/mocks/ERC6551Registry.sol";
import {CharacterAccount} from "../../src/CharacterAccount.sol";

// multi Send
import {MultiSend} from "../../src/lib/MultiSend.sol";
import {Category, Asset} from "../../src/lib/MultiToken.sol";

// hats imports
import {HatsModuleFactory} from "hats-module/HatsModuleFactory.sol";
import {Hats} from "hats-protocol/Hats.sol";

// hats eligibility modules
import {AddressHatsEligibilityModule} from "../../src/mocks/AddressHatsEligibilityModule.sol";
import {ERC721HatsEligibilityModule} from "../../src/mocks/ERC721HatsEligibilityModule.sol";
import {ERC6551HatsEligibilityModule} from "../../src/adaptors/hats-modules/ERC6551HatsEligibilityModule.sol";
import {MultiERC6551HatsEligibilityModule} from "../../src/adaptors/hats-modules/MultiERC6551HatsEligibilityModule.sol";
//test and mocks
import {IMolochDAOV2} from "../../src/interfaces/IMolochDAOV2.sol";
import {MockMolochV2} from "../../src/mocks/MockMoloch.sol";
import {MockSharesToken} from "../../src/mocks/MockSharesToken.sol";

import {Merkle} from "murky/src/Merkle.sol";

contract SetUp is Test, Accounts, TestStructs {
    DeployedContracts public deployments;
    CharacterSheetsFactory public characterSheetsFactory;
    ImplementationAddressStorage public implementationStorage;

    Implementations public implementations;
    Adaptors public adaptors;
    HatsContracts public hatsContracts;
    ERC6551Contracts public erc6551Contracts;

    ClassesData public classData;
    SheetsData public sheetsData;
    ItemsData public itemsData;

    MockMolochV2 public dao;
    Merkle public merkle;
    MockSharesToken public mockShares;

    MultiSend public multisend;

    function setUp() public virtual {
        vm.startPrank(accounts.admin);
        _deployImplementations();
        _deployHatsContracts();
        _deployErc6551Contracts();

        _deployCharacterSheetsFactory();
        _createContracts();

        _initializeContracts(address(deployments.clones), address(dao));
        _activateContracts(address(deployments.clones));
        mockShares = new MockSharesToken();
        // dao.setSharesToken(address(mockShares));
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

        bytes memory craftRequirement = createCraftingRequirement(itemsData.itemIdSoulbound, 1);

        // create craftable item
        itemsData.itemIdCraftable = deployments.items.createItemType(
            createNewItem(true, false, bytes32(keccak256("null")), 1, craftRequirement)
        );

        //create free item
        itemsData.itemIdFree =
            deployments.items.createItemType(createNewItem(false, false, bytes32(0), 1, createEmptyRequiredAssets()));
        mockShares.mint(accounts.player1, 100e18);
        mockShares.mint(accounts.player2, 100e18);
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
            Asset memory asset = Asset(category, assetAddress, assetId, amount);

            bytes[] memory nodes = new bytes[](0);

            requiredAssets = abi.encode(0, asset, nodes);
        }

        return requiredAssets;
    }

    function createEmptyRequiredAssets() public pure returns (bytes memory) {
        bytes memory requiredAssets;

        return requiredAssets;
    }

    function createCraftingRequirement(uint256 itemId, uint256 amount) public pure returns (bytes memory) {
        bytes memory requiredAssets;

        {
            CraftItem[] memory requirements = new CraftItem[](1);
            requirements[0] = CraftItem(itemId, amount);

            requiredAssets = abi.encode(requirements);
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
        dao = new MockMolochV2();
        merkle = new Merkle();

        implementations.characterSheets = new CharacterSheetsImplementation();
        implementations.items = new ItemsImplementation();
        implementations.itemsManager = new ItemsManagerImplementation();
        implementations.experience = new ExperienceImplementation();
        implementations.classes = new ClassesImplementation();
        implementations.clonesAddressStorage = new ClonesAddressStorageImplementation();

        adaptors.molochV2EligibilityAdaptor = new MolochV2EligibilityAdaptor();
        adaptors.molochV3EligibilityAdaptor = new MolochV3EligibilityAdaptor();
        adaptors.classLevelAdaptor = new ClassLevelAdaptor();
        adaptors.hatsAdaptor = new HatsAdaptor();
        implementations.addressModule = new AddressHatsEligibilityModule("v 0.1");
        implementations.erc721Module = new ERC721HatsEligibilityModule("v 0.1");
        implementations.erc6551Module = new ERC6551HatsEligibilityModule("v 0.1");
        implementations.multiErc6551Module = new MultiERC6551HatsEligibilityModule("v 0.1");

        vm.label(address(dao), "Moloch Implementation");
        vm.label(address(merkle), "Merkle Implementation");
        vm.label(address(implementations.characterSheets), "Character Sheets Implementation");
        vm.label(address(implementations.items), "Items Implementation");
        vm.label(address(implementations.itemsManager), "Items Manager Implementation");
        vm.label(address(implementations.experience), "Experience Implementation");
        vm.label(address(implementations.classes), "Classes Implementation");
        vm.label(address(implementations.clonesAddressStorage), "Clones Address Storage Implementation");
        vm.label(address(adaptors.molochV2EligibilityAdaptor), "Character Eligibility adaptor V2 Implementation");
        vm.label(address(adaptors.classLevelAdaptor), "Class Level adaptor Implementation");
        vm.label(address(adaptors.hatsAdaptor), "Hats adaptor Implementation");
        vm.label(address(implementations.addressModule), "Admin Hats Eligibility adaptor Implementation");
        vm.label(address(implementations.erc721Module), "Player Hats Eligibility adaptor Implementation");
        vm.label(address(implementations.erc6551Module), "Character Hats Eligibility adaptor Implementation");
        vm.label(address(implementations.multiErc6551Module), "MULTI Character Hats Eligibility adaptor Implementation");
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

        bytes memory encodedImplementationAddresses = abi.encode(
            address(implementations.characterSheets),
            address(implementations.items),
            address(implementations.classes),
            address(implementations.experience),
            address(implementations.clonesAddressStorage),
            address(implementations.itemsManager),
            address(erc6551Contracts.erc6551Implementation)
        );

        bytes memory encodedModuleAddresses = abi.encode(
            address(implementations.addressModule),
            address(implementations.erc721Module),
            address(implementations.erc6551Module),
            address(implementations.multiErc6551Module)
        );

        bytes memory encodedAdaptorAddresses = abi.encode(
            address(adaptors.hatsAdaptor),
            address(adaptors.molochV2EligibilityAdaptor),
            address(adaptors.molochV3EligibilityAdaptor),
            address(adaptors.classLevelAdaptor)
        );

        bytes memory encodedExternalAddresses = abi.encode(
            address(erc6551Contracts.erc6551Registry),
            address(hatsContracts.hats),
            address(hatsContracts.hatsModuleFactory)
        );
        implementationStorage.initialize(
            encodedImplementationAddresses, encodedModuleAddresses, encodedAdaptorAddresses, encodedExternalAddresses
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

    function createSimpleClaimableItem() public returns (uint256) {
        vm.startPrank(accounts.gameMaster);

        uint256 _itemId1 =
            deployments.items.createItemType(createNewItem(false, false, bytes32(0), 1000, createEmptyRequiredAssets()));

        RequirementNode memory item = RequirementNode({
            operator: 0,
            asset: Asset(Category.ERC1155, address(deployments.items), _itemId1, 100),
            children: new RequirementNode[](0)
        });

        bytes memory requiredAssets = RequirementsTree.encode(item);

        console2.logBytes(requiredAssets);

        uint256 claimableItemId =
            deployments.items.createItemType(createNewItem(false, false, bytes32(0), 10, requiredAssets));

        vm.stopPrank();

        return claimableItemId;
    }

    function createComplexClaimableItem() public returns (uint256) {
        vm.startPrank(accounts.gameMaster);

        uint256 _itemId1 = deployments.items.createItemType(
            createNewItem(false, false, bytes32(0), 10000, createEmptyRequiredAssets())
        );

        uint256 _itemId2 = deployments.items.createItemType(
            createNewItem(false, false, bytes32(0), 10000, createEmptyRequiredAssets())
        );

        // the requirements shall be that the player has 100 of item1 OR 200 of item2 AND between 1000 and 2000 exp
        //
        //                                  AND
        //                 /                                  \
        //               OR                                   AND
        //              /   \                                /   \
        // (100 of item1)   (200 of item2)          (1000 exp)   NOT
        //                                                         \
        //                                                         (2000 exp)
        //
        RequirementNode memory itemOr;

        {
            Asset memory assetItem1 = Asset(Category.ERC1155, address(deployments.items), _itemId1, 100);
            Asset memory assetItem2 = Asset(Category.ERC1155, address(deployments.items), _itemId2, 200);

            RequirementNode memory item1 =
                RequirementNode({operator: 0, asset: assetItem1, children: new RequirementNode[](0)});

            RequirementNode memory item2 =
                RequirementNode({operator: 0, asset: assetItem2, children: new RequirementNode[](0)});

            itemOr = RequirementNode({
                operator: 2,
                asset: Asset(Category.ERC20, address(0), 0, 0),
                children: new RequirementNode[](2)
            });

            itemOr.children[0] = item1;
            itemOr.children[1] = item2;
        }

        RequirementNode memory expRange;

        {
            Asset memory assetExpMin = Asset(Category.ERC20, address(deployments.experience), 0, 1000);
            Asset memory assetExpMax = Asset(Category.ERC20, address(deployments.experience), 0, 2000);

            RequirementNode memory maxExp =
                RequirementNode({operator: 0, asset: assetExpMax, children: new RequirementNode[](0)});

            RequirementNode memory notExpMax = RequirementNode({
                operator: 3,
                asset: Asset(Category.ERC20, address(0), 0, 0),
                children: new RequirementNode[](1)
            });

            RequirementNode memory minExp =
                RequirementNode({operator: 0, asset: assetExpMin, children: new RequirementNode[](0)});

            notExpMax.children[0] = maxExp;

            expRange = RequirementNode({
                operator: 1,
                asset: Asset(Category.ERC20, address(0), 0, 0),
                children: new RequirementNode[](2)
            });

            expRange.children[0] = minExp;
            expRange.children[1] = notExpMax;
        }

        RequirementNode memory and = RequirementNode({
            operator: 1,
            asset: Asset(Category.ERC20, address(0), 0, 0),
            children: new RequirementNode[](2)
        });

        and.children[0] = itemOr;
        and.children[1] = expRange;

        bytes memory requiredAssets = RequirementsTree.encode(and);

        uint256 claimableItemId =
            deployments.items.createItemType(createNewItem(false, false, bytes32(0), 10, requiredAssets));

        vm.stopPrank();

        return claimableItemId;
    }

    function createComplexClaimableItemWithShallowNot() public returns (uint256) {
        vm.startPrank(accounts.gameMaster);

        uint256 _itemId1 = deployments.items.createItemType(
            createNewItem(false, false, bytes32(0), 10000, createEmptyRequiredAssets())
        );

        uint256 _itemId2 = deployments.items.createItemType(
            createNewItem(false, false, bytes32(0), 10000, createEmptyRequiredAssets())
        );

        // the requirements shall be that the player has 100 of item1 OR 200 of item2 AND between 1000 and 2000 exp
        //
        //                                  AND
        //                 /                                  \
        //               OR                                   AND
        //              /   \                                /   \
        // (100 of item1)   (200 of item2)          (1000 exp)   NOT
        //                                                         \
        //                                                         (2000 exp)
        //
        RequirementNode memory itemOr;

        {
            Asset memory assetItem1 = Asset(Category.ERC1155, address(deployments.items), _itemId1, 100);
            Asset memory assetItem2 = Asset(Category.ERC1155, address(deployments.items), _itemId2, 200);

            RequirementNode memory item1 =
                RequirementNode({operator: 0, asset: assetItem1, children: new RequirementNode[](0)});

            RequirementNode memory item2 =
                RequirementNode({operator: 0, asset: assetItem2, children: new RequirementNode[](0)});

            itemOr = RequirementNode({
                operator: 2,
                asset: Asset(Category.ERC20, address(0), 0, 0),
                children: new RequirementNode[](2)
            });

            itemOr.children[0] = item1;
            itemOr.children[1] = item2;
        }

        RequirementNode memory expRange;

        {
            Asset memory assetExpMin = Asset(Category.ERC20, address(deployments.experience), 0, 1000);
            Asset memory assetExpMax = Asset(Category.ERC20, address(deployments.experience), 0, 2000);

            RequirementNode memory notExpMax =
                RequirementNode({operator: 3, asset: assetExpMax, children: new RequirementNode[](0)});

            RequirementNode memory minExp =
                RequirementNode({operator: 0, asset: assetExpMin, children: new RequirementNode[](0)});

            expRange = RequirementNode({
                operator: 1,
                asset: Asset(Category.ERC20, address(0), 0, 0),
                children: new RequirementNode[](2)
            });

            expRange.children[0] = minExp;
            expRange.children[1] = notExpMax;
        }

        RequirementNode memory and = RequirementNode({
            operator: 1,
            asset: Asset(Category.ERC20, address(0), 0, 0),
            children: new RequirementNode[](2)
        });

        and.children[0] = itemOr;
        and.children[1] = expRange;

        bytes memory requiredAssets = RequirementsTree.encode(and);

        uint256 claimableItemId =
            deployments.items.createItemType(createNewItem(false, false, bytes32(0), 10, requiredAssets));

        vm.stopPrank();

        return claimableItemId;
    }
}
