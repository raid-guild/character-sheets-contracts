// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
pragma abicoder v2;

import "forge-std/Test.sol";

import "../src/lib/Structs.sol";
import {Errors} from "../src/lib/Errors.sol";
import {SetUp} from "./helpers/SetUp.sol";
import {HatsErrors} from "hats-protocol/Interfaces/HatsErrors.sol";

// hats imports
import {HatsAdaptor} from "../src/adaptors/HatsAdaptor.sol";
import {HatsModuleFactory} from "hats-module/HatsModuleFactory.sol";
import {Hats} from "hats-protocol/Hats.sol";
import {AdminHatEligibilityModule} from "../src/adaptors/hats_modules/AdminHatEligibilityModule.sol";
import {DungeonMasterHatEligibilityModule} from "../src/adaptors/hats_modules/DungeonMasterHatEligibilityModule.sol";
import {PlayerHatEligibilityModule} from "../src/adaptors/hats_modules/PlayerHatEligibilityModule.sol";
import {CharacterHatEligibilityModule} from "../src/adaptors/hats_modules/CharacterHatEligibilityModule.sol";

contract HatsEligibilityModulesTest is Test, SetUp {
    HatsAdaptor internal _testAdaptor;
    AdminHatEligibilityModule internal _adminModule;
    DungeonMasterHatEligibilityModule internal _dmModule;
    PlayerHatEligibilityModule internal _playerModule;
    CharacterHatEligibilityModule internal _characterModule;

    address public topHatWearer = address(1);
    address public adminHatWearer = address(2);
    address public dmHatWearer = address(3);
    address public playerHatWearer = address(4);
    address public characterHatWearer;

    uint256 internal _testTopHatId;
    uint256 internal _testAdminHatId;
    uint256 internal _testDungeonMasterHatId;
    uint256 internal _testPlayerHatId;
    uint256 internal _testCharacterHatId;

    function createNewHatsAdaptorSetup() public {
        _testAdaptor = HatsAdaptor(characterSheetsFactory.createHatsAdaptor());

        address[] memory _adminArray = new address[](1);
        _adminArray[0] = adminHatWearer;

        address[] memory _dungeonMasterArray = new address[](1);
        _dungeonMasterArray[0] = dmHatWearer;

        // initialize hats adaptor
        bytes memory encodedHatsAddresses = abi.encode(
            address(hats),
            address(hatsModuleFactory),
            storedImp.adminHatEligibilityModuleImplementation,
            storedImp.dungeonMasterHatEligibilityModuleImplementation,
            storedImp.playerHatEligibilityModuleImplementation,
            storedImp.characterHatEligibilityModuleImplementation,
            _adminArray,
            _dungeonMasterArray,
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

        _testAdaptor.initialize(topHatWearer, encodedHatsAddresses, encodedHatsStrings);

        _adminModule = AdminHatEligibilityModule(_testAdaptor.adminHatEligibilityModule());
        _dmModule = DungeonMasterHatEligibilityModule(_testAdaptor.dungeonMasterHatEligibilityModule());
        _characterModule = CharacterHatEligibilityModule(_testAdaptor.characterHatEligibilityModule());
        _playerModule = PlayerHatEligibilityModule(_testAdaptor.playerHatEligibilityModule());

        vm.prank(admin);
        characterSheets.updateHatsAdaptor(address(_testAdaptor));

        dao.addMember(playerHatWearer);
        vm.prank(playerHatWearer);
        uint256 testCharacterId = characterSheets.rollCharacterSheet("test_player_hat_wearer_uri");

        characterHatWearer = characterSheets.getCharacterSheetByCharacterId(testCharacterId).accountAddress;

        HatsData memory newData = _testAdaptor.getHatsData();
        _testTopHatId = newData.topHatId;
        _testAdminHatId = newData.adminHatId;
        _testDungeonMasterHatId = newData.dungeonMasterHatId;
        _testPlayerHatId = newData.playerHatId;
        _testCharacterHatId = newData.characterHatId;
    }

    function testNewModuleSetup() public {
        createNewHatsAdaptorSetup();
        assertEq(_testAdaptor.isAdmin(adminHatWearer), true, "admin is not admin");
        assertEq(_testAdaptor.isDungeonMaster(dmHatWearer), true, "dm is not dm");
        assertEq(_testAdaptor.isPlayer(playerHatWearer), true, "player is not player");
        assertEq(_testAdaptor.isCharacter(characterHatWearer), true, "character is not character");
    }

    function testAddNewAdmin() public {
        createNewHatsAdaptorSetup();
        address[] memory testAdmins = new address[](1);
        testAdmins[0] = dmHatWearer;

        //should revert if called by wrong EOA
        vm.prank(address(420));
        vm.expectRevert();
        _adminModule.addEligibleAddresses(testAdmins);

        //should succeed if called by topHatWearer;
        vm.startPrank(topHatWearer);
        _adminModule.addEligibleAddresses(testAdmins);
        hats.mintHat(_testAdminHatId, dmHatWearer);
        vm.stopPrank();

        assertEq(_testAdaptor.isAdmin(dmHatWearer), true, "new admin not assigned");
    }
}
