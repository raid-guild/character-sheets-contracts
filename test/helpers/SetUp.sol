// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
pragma abicoder v2;
//solhint-disable

import "forge-std/Test.sol";
import "../../src/implementations/ItemsImplementation.sol";
import "../../src/CharacterSheetsFactory.sol";
import "../../src/implementations/CharacterSheetsImplementation.sol";
import "../../src/implementations/ClassesImplementation.sol";
import "../../src/interfaces/IMolochDAO.sol";
import "../../src/mocks/MockMoloch.sol";
// import "../../src/mocks/MockHats.sol";
import "../../src/lib/Structs.sol";
import "../../lib/murky/src/Merkle.sol";
import {ERC6551Registry} from "../../src/mocks/ERC6551Registry.sol";
import {CharacterAccount} from "../../src/CharacterAccount.sol";

import "forge-std/console2.sol";

struct StoredAddresses {
    address characterSheetsImplementation;
    address experienceImplementation;
    address classesImplementation;
    address createdCharacterSheets;
    address createdExperience;
    address createdClasses;
    address factory;
}

contract SetUp is Test {
    using ClonesUpgradeable for address;
    using stdJson for string;

    ItemsImplementation experience;
    CharacterSheetsFactory characterSheetsFactory;
    CharacterSheetsImplementation characterSheets;
    ClassesImplementation classes;

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

    function setUp() public {
        vm.startPrank(admin);

        dao = new Moloch();
        vm.label(address(dao), "Moloch");

        characterSheetsFactory = new CharacterSheetsFactory();
        experience = new ItemsImplementation();
        classes = new ClassesImplementation();
        characterSheets = new CharacterSheetsImplementation();
        characterSheetsFactory.initialize();

        stored.experienceImplementation = address(experience);
        stored.factory = address(characterSheetsFactory);
        stored.classesImplementation = address(classes);
        stored.characterSheetsImplementation = address(characterSheets);

        erc6551Registry = new ERC6551Registry();
        erc6551Implementation = new CharacterAccount();

        dao.addMember(player1);
        dao.addMember(admin);

        characterSheetsFactory.updateCharacterSheetsImplementation(address(stored.characterSheetsImplementation));
        characterSheetsFactory.updateItemsImplementation(address(stored.experienceImplementation));
        characterSheetsFactory.updateClassesImplementation(address(stored.classesImplementation));
        address[] memory dungeonMasters = new address[](1);
        dungeonMasters[0] = admin;
        characterSheetsFactory.updateERC6551Registry(address(erc6551Registry));
        characterSheetsFactory.updateERC6551AccountImplementation(address(erc6551Implementation));

        bytes memory baseUriData = abi.encode(
            "test_metadata_uri_character_sheets/",
            "test_base_uri_character_sheets/",
            "test_base_uri_experience/",
            "test_base_uri_classes/"
        );
        (stored.createdCharacterSheets, stored.createdExperience, stored.createdClasses) =
            characterSheetsFactory.create(dungeonMasters, address(dao), baseUriData);

        characterSheets = CharacterSheetsImplementation(stored.createdCharacterSheets);
        assertEq(address(characterSheets.classes()), stored.createdClasses, "incorrect classes address in setup");
        experience = ItemsImplementation(stored.createdExperience);
        classes = ClassesImplementation(stored.createdClasses);
        characterSheets.setERC6551Registry(address(erc6551Registry));

        testClassId = classes.createClassType(createNewClass("test_class"));

        testItemId = experience.createItemType(createNewItem("test_item", false, bytes32(0)));

        vm.stopPrank();
        bytes memory encodedData = abi.encode("Test Name", "test_token_uri/");
        vm.prank(player1);
        uint256 tokenId1 = characterSheets.rollCharacterSheet(player1, encodedData);
        npc1 = characterSheets.getCharacterSheetByCharacterId(tokenId1).erc6551TokenAddress;

        assertTrue(
            characterSheets.hasRole(keccak256("DUNGEON_MASTER"), admin),
            "wrong dungeon master role assignment for character sheets"
        );
        assertTrue(characterSheets.hasRole(bytes32(0), admin), "wrong ADMIN role assignment for character sheets");
    }

    function dropExp(address player, uint256 amount) public {
        address[] memory players = new address[](1);
        players[0] = player;
        uint256[][] memory itemIds = new uint256[][](1);
        itemIds[0] = new uint256[](1);
        itemIds[0][0] = 0;
        uint256[][] memory amounts = new uint256[][](1);
        amounts[0] = new uint256[](1);
        amounts[0][0] = amount;
        vm.prank(admin);
        experience.dropLoot(players, itemIds, amounts);
    }

    function createNewItemType(string memory name) public returns (uint256 itemId) {
        bytes memory newItem = createNewItem(name, false, bytes32(0));
        itemId = experience.createItemType(newItem);
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

    function createNewItem(string memory _name, bool _soulbound, bytes32 _claimable)
        public
        pure
        returns (bytes memory)
    {
        uint256[][] memory newItemRequirements = new uint256[][](1);
        newItemRequirements[0] = new uint256[](2);
        newItemRequirements[0][0] = 0;
        newItemRequirements[0][1] = 100;

        uint256[] memory newClassRequirements;
        // newClassRequirements[0] = testClassId;
        return abi.encode(
            _name, 10 ** 18, newItemRequirements, newClassRequirements, _soulbound, _claimable, "test_item_cid/"
        );
    }

    function createNewClass(string memory _name) public pure returns (bytes memory data) {
        return abi.encode(_name, true, "test_class_cid/");
    }
}
