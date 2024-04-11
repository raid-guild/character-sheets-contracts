// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
pragma abicoder v2;

import "forge-std/Test.sol";

import "../src/lib/Structs.sol";
import {Errors} from "../src/lib/Errors.sol";
import {SetUp} from "./setup/SetUp.t.sol";
import {HatsErrors} from "hats-protocol/Interfaces/HatsErrors.sol";

// hats imports
import {HatsAdaptor} from "../src/adaptors/HatsAdaptor.sol";
import {HatsModuleFactory} from "hats-module/HatsModuleFactory.sol";
import {Hats} from "hats-protocol/Hats.sol";

// hats eligibility modules
import {AddressHatsEligibilityModule} from "../src/mocks/AddressHatsEligibilityModule.sol";
import {AllowlistEligibility} from "../src/mocks/AllowlistHatsEligibilityModule.sol";
import {ERC721HatsEligibilityModule} from "../src/mocks/ERC721HatsEligibilityModule.sol";
import {ERC6551HatsEligibilityModule} from "../src/adaptors/hats-modules/ERC6551HatsEligibilityModule.sol";
import {MultiERC6551HatsEligibilityModule} from "../src/adaptors/hats-modules/MultiERC6551HatsEligibilityModule.sol";
import {CharacterSheetsLevelEligibilityModule} from
    "../src/adaptors/hats-modules/CharacterSheetsLevelEligibilityModule.sol";
import {IClonesAddressStorage} from "../src/interfaces/IClonesAddressStorage.sol";
import {ICharacterSheets} from "../src/interfaces/ICharacterSheets.sol";
import {IMultiERC6551HatsEligibilityModule} from "../src/interfaces/IMultiERC6551HatsEligibilityModule.sol";

contract Base is SetUp {
    HatsAdaptor public newAdaptor;
    AllowlistEligibility public adminModule;
    AllowlistEligibility public dmModule;
    ERC721HatsEligibilityModule public playerModule;
    ERC6551HatsEligibilityModule public characterModule;
    CharacterSheetsLevelEligibilityModule public elderModule;
    MultiERC6551HatsEligibilityModule public multiModule;

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

        adminModule = AllowlistEligibility(newAdaptor.adminHatEligibilityModule());
        dmModule = AllowlistEligibility(newAdaptor.gameMasterHatEligibilityModule());
        characterModule = ERC6551HatsEligibilityModule(newAdaptor.characterHatEligibilityModule());
        playerModule = ERC721HatsEligibilityModule(newAdaptor.playerHatEligibilityModule());

        vm.prank(accounts.admin);
        deployments.clones.updateHatsAdaptor(address(newAdaptor));

        dao.addMember(playerHatWearer);
        vm.prank(playerHatWearer);
        uint256 testCharacterId =
            deployments.characterSheets.rollCharacterSheet(playerHatWearer, "test_player_hat_wearer_uri");

        characterHatWearer = deployments.characterSheets.getCharacterSheetByCharacterId(testCharacterId).accountAddress;

        HatsData memory newData = newAdaptor.getHatsData();
        newTopHatId = newData.topHatId;
        newAdminHatId = newData.adminHatId;
        newGameMasterHatId = newData.gameMasterHatId;
        newPlayerHatId = newData.playerHatId;
        newCharacterHatId = newData.characterHatId;
    }
}

contract Test_AdminEligibilityModule is Base {
    function setUp() public override {
        super.setUp();
        createNewHatsAdaptorSetup();
    }

    function testAddNewAdmin() public {
        address[] memory testAdmins = new address[](1);
        testAdmins[0] = dmHatWearer;

        //should revert if called by wrong EOA
        vm.startPrank(address(420));
        vm.expectRevert();
        bool[] memory standings = _createStandings(testAdmins.length);
        adminModule.addAccounts(testAdmins);
        vm.stopPrank();
        //should succeed if called by topHatWearer;
        vm.startPrank(topHatWearer);
        adminModule.addAccounts(testAdmins);
        adminModule.setStandingForAccounts(testAdmins, standings);
        hatsContracts.hats.mintHat(newAdminHatId, dmHatWearer);
        vm.stopPrank();

        assertEq(newAdaptor.isAdmin(dmHatWearer), true, "new admin not assigned");
    }

    function testRemoveAdmin() public {
        address[] memory testAdmins = new address[](1);
        testAdmins[0] = dmHatWearer;

        //add new admin
        vm.startPrank(topHatWearer);
        bool[] memory standings = _createStandings(testAdmins.length);
        adminModule.addAccounts(testAdmins);
        adminModule.setStandingForAccounts(testAdmins, standings);
        hatsContracts.hats.mintHat(newAdminHatId, dmHatWearer);
        vm.stopPrank();

        //should revert if called by wrong EOA
        vm.expectRevert();
        vm.prank(adminHatWearer);
        adminModule.removeAccounts(testAdmins);

        //should succeed if called by top hat wearer;
        vm.prank(topHatWearer);
        adminModule.removeAccounts(testAdmins);

        assertEq(newAdaptor.isAdmin(dmHatWearer), false, "admin hat not removed");
    }
}

contract Test_GameMasterEligibilityModule is Base {
    function setUp() public override {
        super.setUp();
        createNewHatsAdaptorSetup();
    }

    function testNewModuleSetup() public view {
        assertEq(newAdaptor.isAdmin(adminHatWearer), true, "admin is not admin");
        assertEq(newAdaptor.isGameMaster(dmHatWearer), true, "dm is not dm");
        assertEq(newAdaptor.isPlayer(playerHatWearer), true, "player is not player");
        assertEq(newAdaptor.isCharacter(characterHatWearer), true, "character is not character");
    }

    function testAddNewGameMaster() public {
        address[] memory testAdmins = new address[](1);
        testAdmins[0] = address(420);

        //should revert if called by wrong EOA
        vm.startPrank(address(420));
        vm.expectRevert();
        dmModule.addAccounts(testAdmins);
        vm.stopPrank();
        //should succeed if called by topHatWearer;
        bool[] memory standings = _createStandings(testAdmins.length);
        vm.startPrank(adminHatWearer);
        dmModule.addAccounts(testAdmins);
        dmModule.setStandingForAccounts(testAdmins, standings);
        hatsContracts.hats.mintHat(newGameMasterHatId, testAdmins[0]);
        vm.stopPrank();

        assertEq(newAdaptor.isGameMaster(testAdmins[0]), true, "new admin not assigned");
    }

    function testRemoveGameMaster() public {
        address[] memory testAdmins = new address[](1);
        testAdmins[0] = address(420);

        vm.startPrank(adminHatWearer);
        bool[] memory standings = _createStandings(testAdmins.length);
        dmModule.addAccounts(testAdmins);
        dmModule.setStandingForAccounts(testAdmins, standings);
        vm.stopPrank();

        //should revert if called by wrong EOA
        vm.expectRevert();
        vm.prank(dmHatWearer);
        dmModule.removeAccounts(testAdmins);

        //should succeed if called by admin hat wearer;
        vm.prank(adminHatWearer);
        dmModule.removeAccounts(testAdmins);

        assertEq(newAdaptor.isGameMaster(testAdmins[0]), false, "admin hat not removed");
    }
}

contract Test_ElderEligibilityModule is Base {
    address public elderModuleImplementation;
    uint256 public elderModId;
    address public elderModAddress;

    function setUp() public override {
        super.setUp();
        elderModuleImplementation = address(new CharacterSheetsLevelEligibilityModule("V1"));
        elderModId = hatsContracts.hats.getNextId(deployments.hatsAdaptor.getHatsData().gameMasterHatId);

        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[1] = 1;

        uint256[] memory balances = new uint256[](2);
        balances[0] = 2;
        balances[1] = 3;

        bytes memory immutableArgs =
            abi.encodePacked(address(deployments.classes), address(deployments.characterSheets));

        bytes memory initData = abi.encode(tokenIds, balances);

        elderModAddress = hatsContracts.hatsModuleFactory.createHatsModule(
            elderModuleImplementation, elderModId, immutableArgs, initData, uint256(0)
        );
    }

    function testCharacterSheetsLevelEligibilityModule() public {
        vm.startPrank(accounts.admin);
        CharacterSheetsLevelEligibilityModule elderMod = CharacterSheetsLevelEligibilityModule(elderModAddress);
        uint256 elderHat = hatsContracts.hats.createHat(
            deployments.hatsAdaptor.getHatsData().gameMasterHatId,
            "elder Hat",
            100,
            elderModAddress,
            accounts.admin,
            true,
            "test_hats_uri"
        );
        vm.stopPrank();
        assertEq(elderHat, elderModId, "wrong elder hat Id");
        assertEq(elderMod.classIds(1), 1, "incorrect classes id init");
        assertEq(elderMod.minLevels(0), 2, "incorrect min level init");

        // assign classes to potential elder
        vm.startPrank(accounts.gameMaster);
        deployments.classes.assignClass(accounts.character1, 0);
        deployments.classes.assignClass(accounts.character1, 1);

        assertEq(deployments.classes.balanceOf(accounts.character1, 0), 1);
        assertEq(deployments.classes.balanceOf(accounts.character1, 1), 1);
        // should revert because class is too low level
        vm.stopPrank();

        vm.prank(accounts.admin);
        vm.expectRevert();
        hatsContracts.hats.mintHat(elderHat, accounts.player1);

        //level class 2
        vm.startPrank(accounts.gameMaster);
        deployments.classes.giveClassExp(accounts.character1, 1, 2000);

        vm.stopPrank();

        // mint hat to elder
        vm.prank(accounts.gameMaster);
        hatsContracts.hats.mintHat(elderHat, accounts.player1);

        assertTrue(hatsContracts.hats.isWearerOfHat(accounts.player1, elderHat));
    }

    function testElderModuleNoCharacter() public {
        vm.startPrank(accounts.admin);
        CharacterSheetsLevelEligibilityModule elderMod = CharacterSheetsLevelEligibilityModule(elderModAddress);
        uint256 elderHat = hatsContracts.hats.createHat(
            deployments.hatsAdaptor.getHatsData().gameMasterHatId,
            "elder Hat",
            100,
            elderModAddress,
            accounts.admin,
            true,
            "test_hats_uri"
        );
        vm.stopPrank();
        assertEq(elderHat, elderModId, "wrong elder hat Id");
        assertEq(elderMod.classIds(1), 1, "incorrect classes id init");
        assertEq(elderMod.minLevels(0), 2, "incorrec min level init");

        vm.startPrank(accounts.gameMaster);
        uint256[] memory newClasses = new uint256[](2);
        uint256[] memory newMinLevels = new uint256[](2);

        uint256 newClass1 = deployments.classes.createClassType(createNewClass(true));
        uint256 newClass2 = deployments.classes.createClassType(createNewClass(true));

        newClasses[0] = newClass1;
        newClasses[1] = newClass2;
        newMinLevels[0] = 1;
        newMinLevels[1] = 2;

        //add class to elder module

        elderMod.addClasses(newClasses, newMinLevels);

        vm.startPrank(accounts.rando);
        elderMod.getWearerStatus(accounts.rando, elderHat);
    }

    function testAddClassToElderModule() public {
        vm.startPrank(accounts.admin);
        CharacterSheetsLevelEligibilityModule elderMod = CharacterSheetsLevelEligibilityModule(elderModAddress);
        uint256 elderHat = hatsContracts.hats.createHat(
            deployments.hatsAdaptor.getHatsData().gameMasterHatId,
            "elder Hat",
            100,
            elderModAddress,
            accounts.admin,
            true,
            "test_hats_uri"
        );
        vm.stopPrank();
        assertEq(elderHat, elderModId, "wrong elder hat Id");
        assertEq(elderMod.classIds(1), 1, "incorrect classes id init");
        assertEq(elderMod.minLevels(0), 2, "incorrec min level init");

        vm.startPrank(accounts.gameMaster);
        uint256[] memory newClasses = new uint256[](2);
        uint256[] memory newMinLevels = new uint256[](2);

        uint256 newClass1 = deployments.classes.createClassType(createNewClass(true));
        uint256 newClass2 = deployments.classes.createClassType(createNewClass(true));

        newClasses[0] = newClass1;
        newClasses[1] = newClass2;
        newMinLevels[0] = 1;
        newMinLevels[1] = 2;

        //add class to elder module

        elderMod.addClasses(newClasses, newMinLevels);

        assertEq(elderMod.classIds(2), newClass1, "incorrect class added");
        assertEq(elderMod.classIds(3), newClass2, "incorrect class 2 added");
        assertEq(elderMod.minLevels(2), 1, "incorrect level added");
        assertEq(elderMod.minLevels(3), 2, "incorrect level 2 added");
    }
}

// contract Test_MultiErc6551HatsEligibilityModule is Base {
//     address public newCharacterSheets;
//     address public newClonesStorage;
//     IClonesAddressStorage public newClones;
//     ICharacterSheets public newSheets;
//     uint256 public newCharId;
//     address public newCharAccount;
//     IMultiERC6551HatsEligibilityModule public multiERC6551Module;

//     function setUp() public override {
//         super.setUp();

//         (address _newClones) = _deployNewCharacterSheets();

//         newClones = IClonesAddressStorage(_newClones);
//         newSheets = ICharacterSheets(newClones.characterSheets());

//         vm.prank(accounts.rando);
//         (newCharAccount, newCharId) = _rollNewCharacter(address(newSheets));

//         vm.prank(accounts.gameMaster);
//         multiERC6551Module = IMultiERC6551HatsEligibilityModule(deployments.hatsAdaptor.characterHatEligibilityModule());
//     }

//     function _deployNewCharacterSheets() internal returns (address _clonesStorage) {
//         bytes memory encodedHatsStrings = abi.encode(
//             "new_new_test_hats_base_img",
//             "new_test tophat description",
//             "new_test_admin_uri",
//             "new_test_admin_description",
//             "new_test_game_uri",
//             "new_test_game_description",
//             "new_test_player_uri",
//             "new_test_player_description",
//             "new_test_character_uri",
//             "new_test_character_description"
//         );

//         bytes memory encodedSheetsStrings = abi.encode(
//             "new_test_metadata_uri_character_sheets/",
//             "new_test_base_uri_character_sheets/",
//             "new_test_base_uri_items/",
//             "new_test_base_uri_classes/"
//         );

//         address[] memory adminArray = createAddressMemoryArray(1);
//         adminArray[0] = adminHatWearer;

//         address[] memory gameMastersArray = createAddressMemoryArray(1);
//         gameMastersArray[0] = dmHatWearer;

//         vm.prank(accounts.admin);
//         _clonesStorage = characterSheetsFactory.createAndInitialize(
//             address(0), adminArray, gameMastersArray, encodedHatsStrings, encodedSheetsStrings
//         );
//     }

//     function _rollNewCharacter(address _sheets) internal returns (address charAccount, uint256 charId) {
//         ICharacterSheets sheets = ICharacterSheets(_sheets);
//         charId = sheets.rollCharacterSheet("new_test_uri");
//         charAccount = sheets.getCharacterSheetByCharacterId(charId).accountAddress;
//     }

//     function test_checkEligAfterGameIsRemoved() public {
//         (address _newClones) = _deployNewCharacterSheets();
//         IClonesAddressStorage anotherClones = IClonesAddressStorage(_newClones);
//         address newSheetsAddress = anotherClones.characterSheets();

//         vm.prank(accounts.admin);
//         multiERC6551Module.addValidGame(newSheetsAddress);

//         assertEq(multiERC6551Module.totalValidGames(), 3, "game not added");

//         address newRando = address(11111);

//         dao.addMember(newRando);

//         vm.prank(newRando);
//         (address charAcc, uint256 charTokenId) = _rollNewCharacter(newSheetsAddress);
//         vm.prank(accounts.admin);

//         multiERC6551Module.removeGame(2);
//     }
// }
