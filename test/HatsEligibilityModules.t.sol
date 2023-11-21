// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
pragma abicoder v2;

import "forge-std/Test.sol";

import "../src/lib/Structs.sol";
import {Errors} from "../src/lib/Errors.sol";
import {SetUp} from "./setup/SetUp.sol";
import {HatsErrors} from "hats-protocol/Interfaces/HatsErrors.sol";

// hats imports
import {HatsAdaptor} from "../src/adaptors/HatsAdaptor.sol";
import {HatsModuleFactory} from "hats-module/HatsModuleFactory.sol";
import {Hats} from "hats-protocol/Hats.sol";

// hats eligibility modules
import {AddressHatsEligibilityModule} from "../src/mocks/AddressHatsEligibilityModule.sol";
import {ERC721HatsEligibilityModule} from "../src/mocks/ERC721HatsEligibilityModule.sol";
import {ERC6551HatsEligibilityModule} from "../src/adaptors/hats-modules/ERC6551HatsEligibilityModule.sol";

contract HatsEligibilityModulesTest is SetUp {
    HatsAdaptor public newAdaptor;
    AddressHatsEligibilityModule public adminModule;
    AddressHatsEligibilityModule public dmModule;
    ERC721HatsEligibilityModule public playerModule;
    ERC6551HatsEligibilityModule public characterModule;

    address public topHatWearer = address(1);
    address public adminHatWearer = address(2);
    address public dmHatWearer = address(3);
    address public playerHatWearer = address(4);
    address public characterHatWearer;

    uint256 public newTopHatId;
    uint256 public newAdminHatId;
    uint256 public newGameMasterHatId;
    uint256 public newPlayerHatId;
    uint256 public newCharacterHatId;

    function createNewHatsAdaptorSetup() public {
        newAdaptor = HatsAdaptor(characterSheetsFactory.createHatsAdaptor());

        address[] memory _adminArray = new address[](1);
        _adminArray[0] = adminHatWearer;

        address[] memory _gameMasterArray = new address[](1);
        _gameMasterArray[0] = dmHatWearer;

        bytes memory encodedHatsAddresses =
            abi.encode(_adminArray, _gameMasterArray, address(implementationStorage), address(deployments.clones));

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
        bytes memory customModuleAddresses = abi.encode(address(0), address(0), address(0), address(0));

        newAdaptor.initialize(topHatWearer, encodedHatsAddresses, encodedHatsStrings, customModuleAddresses);

        adminModule = AddressHatsEligibilityModule(newAdaptor.adminHatEligibilityModule());
        dmModule = AddressHatsEligibilityModule(newAdaptor.gameMasterHatEligibilityModule());
        characterModule = ERC6551HatsEligibilityModule(newAdaptor.characterHatEligibilityModule());
        playerModule = ERC721HatsEligibilityModule(newAdaptor.playerHatEligibilityModule());

        vm.prank(accounts.admin);
        deployments.clones.updateHatsAdaptor(address(newAdaptor));

        dao.addMember(playerHatWearer);
        vm.prank(playerHatWearer);
        uint256 testCharacterId = deployments.characterSheets.rollCharacterSheet("test_player_hat_wearer_uri");

        characterHatWearer = deployments.characterSheets.getCharacterSheetByCharacterId(testCharacterId).accountAddress;

        HatsData memory newData = newAdaptor.getHatsData();
        newTopHatId = newData.topHatId;
        newAdminHatId = newData.adminHatId;
        newGameMasterHatId = newData.gameMasterHatId;
        newPlayerHatId = newData.playerHatId;
        newCharacterHatId = newData.characterHatId;
    }

    function testNewModuleSetup() public {
        createNewHatsAdaptorSetup();
        assertEq(newAdaptor.isAdmin(adminHatWearer), true, "admin is not admin");
        assertEq(newAdaptor.isGameMaster(dmHatWearer), true, "dm is not dm");
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
        hatsContracts.hats.mintHat(newAdminHatId, dmHatWearer);
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
        hatsContracts.hats.mintHat(newAdminHatId, dmHatWearer);
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

    function testAddNewGameMaster() public {
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
        hatsContracts.hats.mintHat(newGameMasterHatId, adminHatWearer);
        vm.stopPrank();

        assertEq(newAdaptor.isAdmin(adminHatWearer), true, "new admin not assigned");
    }

    function testRemoveGameMaster() public {
        createNewHatsAdaptorSetup();
        address[] memory testAdmins = new address[](1);
        testAdmins[0] = adminHatWearer;

        //add new admin
        vm.startPrank(topHatWearer);
        dmModule.addEligibleAddresses(testAdmins);
        hatsContracts.hats.mintHat(newGameMasterHatId, adminHatWearer);
        vm.stopPrank();

        //should revert if called by wrong EOA
        vm.expectRevert();
        vm.prank(dmHatWearer);
        dmModule.removeEligibleAddresses(testAdmins);

        //should succeed if called by admin hat wearer;
        vm.prank(adminHatWearer);
        dmModule.removeEligibleAddresses(testAdmins);

        assertEq(newAdaptor.isGameMaster(adminHatWearer), false, "admin hat not removed");
    }
}
