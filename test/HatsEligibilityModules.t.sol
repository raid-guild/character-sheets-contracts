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
    HatsAdaptor public newAdaptor;
    AdminHatEligibilityModule public adminModule;
    DungeonMasterHatEligibilityModule public dmModule;
    PlayerHatEligibilityModule public playerModule;
    CharacterHatEligibilityModule public characterModule;

    address public topHatWearer = address(1);
    address public adminHatWearer = address(2);
    address public dmHatWearer = address(3);
    address public playerHatWearer = address(4);
    address public characterHatWearer;

    uint256 public newTopHatId;
    uint256 public newAdminHatId;
    uint256 public newDungeonMasterHatId;
    uint256 public newPlayerHatId;
    uint256 public newCharacterHatId;

    function createNewHatsAdaptorSetup() public {
        newAdaptor = HatsAdaptor(characterSheetsFactory.createHatsAdaptor());

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

        newAdaptor.initialize(topHatWearer, encodedHatsAddresses, encodedHatsStrings);

        adminModule = AdminHatEligibilityModule(newAdaptor.adminHatEligibilityModule());
        dmModule = DungeonMasterHatEligibilityModule(newAdaptor.dungeonMasterHatEligibilityModule());
        characterModule = CharacterHatEligibilityModule(newAdaptor.characterHatEligibilityModule());
        playerModule = PlayerHatEligibilityModule(newAdaptor.playerHatEligibilityModule());

        vm.prank(admin);
        characterSheets.updateHatsAdaptor(address(newAdaptor));

        dao.addMember(playerHatWearer);
        vm.prank(playerHatWearer);
        uint256 testCharacterId = characterSheets.rollCharacterSheet("test_player_hat_wearer_uri");

        characterHatWearer = characterSheets.getCharacterSheetByCharacterId(testCharacterId).accountAddress;

        HatsData memory newData = newAdaptor.getHatsData();
        newTopHatId = newData.topHatId;
        newAdminHatId = newData.adminHatId;
        newDungeonMasterHatId = newData.dungeonMasterHatId;
        newPlayerHatId = newData.playerHatId;
        newCharacterHatId = newData.characterHatId;
    }

    function testNewModuleSetup() public {
        createNewHatsAdaptorSetup();
        assertEq(newAdaptor.isAdmin(adminHatWearer), true, "admin is not admin");
        assertEq(newAdaptor.isDungeonMaster(dmHatWearer), true, "dm is not dm");
        assertEq(newAdaptor.isPlayer(playerHatWearer), true, "player is not player");
        assertEq(newAdaptor.isCharacter(characterHatWearer), true, "character is not character");
    }

    function testAddNewAdmin() public {
        createNewHatsAdaptorSetup();
        address[] memory testAdmins = new address[](1);
        testAdmins[0] = dmHatWearer;

        //should revert if called by wrong EOA
        vm.prank(address(420));
        vm.expectRevert();
        adminModule.addEligibleAddresses(testAdmins);

        //should succeed if called by topHatWearer;
        vm.startPrank(topHatWearer);
        adminModule.addEligibleAddresses(testAdmins);
        hats.mintHat(newAdminHatId, dmHatWearer);
        vm.stopPrank();

        assertEq(newAdaptor.isAdmin(dmHatWearer), true, "new admin not assigned");
    }

    function testRemoveAdmin() public {
        createNewHatsAdaptorSetup();
        address[] memory testAdmins = new address[](1);
        testAdmins[0] = dmHatWearer;

        //add new admin
        vm.startPrank(topHatWearer);
        adminModule.addEligibleAddresses(testAdmins);
        hats.mintHat(newAdminHatId, dmHatWearer);
        vm.stopPrank();

        //should revert if called by wrong EOA
        vm.expectRevert();
        vm.prank(adminHatWearer);
        adminModule.removeEligibleAddresses(testAdmins);

        //should succeed if called by top hat wearer;
        vm.prank(topHatWearer);
        adminModule.removeEligibleAddresses(testAdmins);

        assertEq(newAdaptor.isAdmin(dmHatWearer), false, "admin hat not removed");
    }

    function testAddNewDungeonMaster() public {
        createNewHatsAdaptorSetup();
        address[] memory testAdmins = new address[](1);
        testAdmins[0] = adminHatWearer;

        //should revert if called by wrong EOA
        vm.prank(address(420));
        vm.expectRevert();
        dmModule.addEligibleAddresses(testAdmins);

        //should succeed if called by topHatWearer;
        vm.startPrank(topHatWearer);
        dmModule.addEligibleAddresses(testAdmins);
        hats.mintHat(newDungeonMasterHatId, adminHatWearer);
        vm.stopPrank();

        assertEq(newAdaptor.isAdmin(adminHatWearer), true, "new admin not assigned");
    }

    function testRemoveDungeonMaster() public {
        createNewHatsAdaptorSetup();
        address[] memory testAdmins = new address[](1);
        testAdmins[0] = adminHatWearer;

        //add new admin
        vm.startPrank(topHatWearer);
        dmModule.addEligibleAddresses(testAdmins);
        hats.mintHat(newDungeonMasterHatId, adminHatWearer);
        vm.stopPrank();

        //should revert if called by wrong EOA
        vm.expectRevert();
        vm.prank(dmHatWearer);
        dmModule.removeEligibleAddresses(testAdmins);

        //should succeed if called by admin hat wearer;
        vm.prank(adminHatWearer);
        dmModule.removeEligibleAddresses(testAdmins);

        assertEq(newAdaptor.isDungeonMaster(adminHatWearer), false, "admin hat not removed");
    }
}
