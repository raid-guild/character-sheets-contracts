// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
pragma abicoder v2;
//solhint-disable

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "../../src/implementations/ItemsImplementation.sol";
import "../../src/implementations/ExperienceImplementation.sol";
import "../../src/CharacterSheetsFactory.sol";
import "../../src/EligibilityAdaptor.sol";
import "../../src/implementations/CharacterSheetsImplementation.sol";
import "../../src/implementations/ClassesImplementation.sol";
import "../../src/interfaces/IMolochDAO.sol";
import "../../src/mocks/MockMoloch.sol";
// import "../../src/mocks/MockHats.sol";
import "../../src/lib/Structs.sol";
import "murky/src/Merkle.sol";
import {ERC6551Registry} from "../../src/mocks/ERC6551Registry.sol";
import {CharacterAccount} from "../../src/CharacterAccount.sol";
import {MultiSend} from "../../src/lib/MultiSend.sol";

struct StoredAddresses {
    address characterSheetsImplementation;
    address experienceImplementation;
    address itemsImplementation;
    address classesImplementation;
    address createdCharacterSheets;
    address createdItems;
    address createdClasses;
    address createdExperience;
    address factory;
}

contract SetUp is Test {
    using stdJson for string;

    ItemsImplementation items;
    CharacterSheetsFactory characterSheetsFactory;
    CharacterSheetsImplementation characterSheets;
    ExperienceImplementation experience;
    ClassesImplementation classes;
    EligibilityAdaptor eligibility;

    StoredAddresses public stored;

    address admin = address(0xdeadce11);
    address player1 = address(0xbeef);
    address player2 = address(0xbabe);
    address rando = address(0xc0ffee);
    address npc1;
    uint256 testClassId;
    uint256 testItemId;
    Moloch dao;

    Merkle merkle = new Merkle();

    ERC6551Registry erc6551Registry;
    CharacterAccount erc6551Implementation;
    MultiSend multiSend;

    function setUp() public {
        vm.startPrank(admin);

        dao = new Moloch();

        eligibility = new EligibilityAdaptor();

        eligibility.updateDaoAddress(address(dao));

        vm.label(address(dao), "Moloch");
        vm.label(address(eligibility), "Eligibility Adaptor");

        characterSheetsFactory = new CharacterSheetsFactory();
        items = new ItemsImplementation();
        classes = new ClassesImplementation();
        characterSheets = new CharacterSheetsImplementation();
        experience = new ExperienceImplementation();

        characterSheetsFactory.initialize();

        stored.itemsImplementation = address(items);
        stored.factory = address(characterSheetsFactory);
        stored.classesImplementation = address(classes);
        stored.characterSheetsImplementation = address(characterSheets);
        stored.experienceImplementation = address(experience);

        erc6551Registry = new ERC6551Registry();
        erc6551Implementation = new CharacterAccount();
        multiSend = new MultiSend();

        dao.addMember(player1);
        dao.addMember(admin);

        characterSheetsFactory.updateCharacterSheetsImplementation(address(stored.characterSheetsImplementation));
        characterSheetsFactory.updateItemsImplementation(address(stored.itemsImplementation));
        characterSheetsFactory.updateClassesImplementation(address(stored.classesImplementation));
        characterSheetsFactory.updateExperienceImplementation(address(stored.experienceImplementation));
        address[] memory dungeonMasters = new address[](1);
        dungeonMasters[0] = admin;
        characterSheetsFactory.updateERC6551Registry(address(erc6551Registry));
        characterSheetsFactory.updateERC6551AccountImplementation(address(erc6551Implementation));

        bytes memory baseUriData = abi.encode(
            "test_metadata_uri_character_sheets/",
            "test_base_uri_character_sheets/",
            "test_base_uri_items/",
            "test_base_uri_classes/"
        );
        (stored.createdCharacterSheets, stored.createdItems, stored.createdExperience, stored.createdClasses) =
            characterSheetsFactory.create(dungeonMasters, address(eligibility), baseUriData);

        characterSheets = CharacterSheetsImplementation(stored.createdCharacterSheets);
        assertEq(address(characterSheets.classes()), stored.createdClasses, "incorrect classes address in setup");
        items = ItemsImplementation(stored.createdItems);
        classes = ClassesImplementation(stored.createdClasses);
        experience = ExperienceImplementation(stored.createdExperience);

        characterSheets.setERC6551Registry(address(erc6551Registry));

        testClassId = classes.createClassType(createNewClass("test_class"));

        testItemId = items.createItemType(createNewItem("test_item", false, false, bytes32(0)));
        vm.stopPrank();
        bytes memory encodedData = abi.encode("Test Name", "test_token_uri/");
        vm.prank(player1);
        uint256 tokenId1 = characterSheets.rollCharacterSheet(player1, encodedData);
        assertEq(tokenId1, 1);
        npc1 = characterSheets.getCharacterSheetByCharacterId(tokenId1).erc6551TokenAddress;

        assertTrue(
            characterSheets.hasRole(keccak256("DUNGEON_MASTER"), admin),
            "wrong dungeon master role assignment for character sheets"
        );
        assertTrue(characterSheets.hasRole(bytes32(0), admin), "wrong ADMIN role assignment for character sheets");
    }

    function dropExp(address player, uint256 amount) public {
        vm.prank(admin);
        experience.dropExp(player, amount);
    }

    function createNewItemType(string memory name) public returns (uint256 itemId) {
        bytes memory newItem = createNewItem(name, false, false, bytes32(0));
        itemId = items.createItemType(newItem);
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

    function createNewItem(string memory name, bool craftable, bool soulbound, bytes32 claimable)
        public
        view
        returns (bytes memory)
    {
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

        return abi.encode(
            craftable, soulbound, claimable, 10 ** 18, abi.encodePacked("test_item_cid/", name), requiredAssets
        );
    }

    function createNewClass(string memory _name) public pure returns (bytes memory data) {
        return abi.encode(_name, true, "test_class_cid/");
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
}
