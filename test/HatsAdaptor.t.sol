// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
pragma abicoder v2;

import "forge-std/Test.sol";

import "../src/lib/Structs.sol";
import {Errors} from "../src/lib/Errors.sol";
import {SetUp, ClonesAddressStorageImplementation, HatsAdaptor, HatsData} from "./setup/SetUp.sol";
import {HatsErrors} from "hats-protocol/Interfaces/HatsErrors.sol";

contract HatsAdaptorTest is SetUp {
    function testHatsAdaptorDeployment() public {
        vm.expectRevert();
        bytes memory customModuleAddresses = abi.encode(address(0), address(0), address(0), address(0));

        deployments.hatsAdaptor.initialize(
            accounts.admin, abi.encode("fake addressdata"), abi.encode("fake string data"), customModuleAddresses
        );

        HatsData memory _hatsData = deployments.hatsAdaptor.getHatsData();

        assertEq(
            hatsContracts.hats.isAdminOfHat(accounts.admin, _hatsData.adminHatId), true, "incorrect admin hat admin"
        );
        assertEq(
            hatsContracts.hats.isAdminOfHat(address(deployments.hatsAdaptor), _hatsData.gameMasterHatId),
            true,
            "incorrect game master admin"
        );
        assertEq(
            hatsContracts.hats.isAdminOfHat(address(deployments.hatsAdaptor), _hatsData.playerHatIds[0]),
            true,
            "incorrect player admin"
        );
        assertEq(
            hatsContracts.hats.isAdminOfHat(address(deployments.hatsAdaptor), _hatsData.characterHatIds[0]),
            true,
            "incorrect character admin"
        );
        assertTrue(
            hatsContracts.hats.isWearerOfHat(address(deployments.hatsAdaptor), _hatsData.adminHatId),
            "contract not admin"
        );
        assertTrue(hatsContracts.hats.isWearerOfHat(accounts.admin, _hatsData.topHatId), "admin not tophat wearer");
    }

    function testMintPlayerHat() public {
        HatsData memory _hatsData = deployments.hatsAdaptor.getHatsData();
        //should revert if player is already wearing a hat
        vm.expectRevert(
            abi.encodeWithSelector(HatsErrors.AlreadyWearingHat.selector, accounts.player1, _hatsData.playerHatIds[0])
        );
        deployments.hatsAdaptor.mintPlayerHat(accounts.player1);

        //should revert if player is ineligible for hat
        vm.expectRevert(Errors.PlayerError.selector);
        deployments.hatsAdaptor.mintPlayerHat(accounts.rando);

        //should mint hat when player rolls character sheet
        dao.addMember(accounts.rando);

        vm.prank(accounts.rando);
        deployments.characterSheets.rollCharacterSheet("rando_token_uri");

        assertTrue(
            hatsContracts.hats.isWearerOfHat(accounts.rando, _hatsData.playerHatIds[0]), "not wearing player hat"
        );
    }

    function testMintCharacterHat() public {
        HatsData memory _hatsData = deployments.hatsAdaptor.getHatsData();
        //should revert if character is already wearing a character hat
        vm.expectRevert(
            abi.encodeWithSelector(
                HatsErrors.AlreadyWearingHat.selector, accounts.character1, _hatsData.characterHatIds[0]
            )
        );
        deployments.hatsAdaptor.mintCharacterHat(accounts.character1);

        //should revert if address is ineligible for hat
        vm.expectRevert(Errors.CharacterError.selector);
        deployments.hatsAdaptor.mintCharacterHat(accounts.rando);

        //should mint character hat when sheet is rolled
        assertTrue(
            hatsContracts.hats.isWearerOfHat(accounts.character1, _hatsData.characterHatIds[0]),
            "not wearing character hat"
        );
    }

    function testIsPlayer() public {
        assertTrue(deployments.hatsAdaptor.isPlayer(accounts.player1), "player one should be a player");
        assertFalse(deployments.hatsAdaptor.isPlayer(accounts.rando), "player two should not be a player.");
        assertFalse(deployments.hatsAdaptor.isPlayer(accounts.character1), "npc1 should not be a player.");
        assertFalse(deployments.hatsAdaptor.isPlayer(accounts.admin), "admin should not be a player.");
    }

    function testIsCharacter() public {
        assertTrue(deployments.hatsAdaptor.isCharacter(accounts.character1), "npc one should be a character");
        assertFalse(deployments.hatsAdaptor.isCharacter(accounts.player1), "player one should not be a character.");
        assertFalse(deployments.hatsAdaptor.isCharacter(accounts.admin), "admin should not be a character.");
    }

    function testIsGameMaster() public {
        assertTrue(deployments.hatsAdaptor.isGameMaster(accounts.gameMaster), "admin should be a GameMaster");
        assertFalse(deployments.hatsAdaptor.isGameMaster(accounts.player1), "player one should not be a GameMaster.");
        assertFalse(deployments.hatsAdaptor.isGameMaster(accounts.character1), "npc1 should not be a GameMaster.");
    }

    function testAddGameMaster() public {
        address[] memory gameMasters = createAddressMemoryArray(1);
        gameMasters[0] = accounts.rando;
        vm.prank(accounts.admin);
        deployments.hatsAdaptor.addGameMasters(gameMasters);

        assertEq(deployments.hatsAdaptor.isGameMaster(accounts.rando), true, "rando not gm");
    }

    function testAddNewGame() public {
        bytes memory encodedHatsStrings = abi.encode(
            "new_new_test_hats_base_img",
            "new_test tophat description",
            "new_test_admin_uri",
            "new_test_admin_description",
            "new_test_game_uri",
            "new_test_game_description",
            "new_test_player_uri",
            "new_test_player_description",
            "new_test_character_uri",
            "new_test_character_description"
        );

        bytes memory encodedSheetsStrings = abi.encode(
            "new_test_metadata_uri_character_sheets/",
            "new_test_base_uri_character_sheets/",
            "new_test_base_uri_items/",
            "new_test_base_uri_classes/"
        );

        address[] memory adminArray = createAddressMemoryArray(1);
        adminArray[0] = accounts.admin;

        address[] memory gameMastersArray = createAddressMemoryArray(1);
        gameMastersArray[0] = accounts.gameMaster;

        vm.prank(accounts.player2);
        address newClonesStorage = characterSheetsFactory.createAndInitialize(
            address(dao), adminArray, gameMastersArray, encodedHatsStrings, encodedSheetsStrings
        );

        ClonesAddressStorageImplementation clones = ClonesAddressStorageImplementation(newClonesStorage);

        HatsAdaptor newAdaptor = HatsAdaptor(clones.hatsAdaptor());

        HatsData memory oldData = deployments.hatsAdaptor.getHatsData();

        vm.prank(accounts.admin);
        newAdaptor.addHatsIds(oldData.playerHatIds[0], oldData.characterHatIds[0]);

        HatsData memory newData = newAdaptor.getHatsData();

        assertEq(newData.playerHatIds.length, 2, "new player id not added");
        assertEq(newData.characterHatIds.length, 2, "new character id not added");
        assertEq(newAdaptor.isCharacter(accounts.character1), true, "old character not valid");
        assertEq(newAdaptor.isPlayer(accounts.player1), true, "old player not valid");
        assertEq(newAdaptor.isPlayer(accounts.rando), false, "rando is player?");
    }

    function testRemoveGameIds() public {
        vm.prank(accounts.admin);
        deployments.hatsAdaptor.addHatsIds(1, 1);

        HatsData memory modifiedData = deployments.hatsAdaptor.getHatsData();

        assertEq(modifiedData.playerHatIds.length, 2, "new player id not added");
        assertEq(modifiedData.characterHatIds.length, 2, "new character id not added");

        vm.prank(accounts.admin);
        deployments.hatsAdaptor.removeHatsIds(1, 1);

        modifiedData = deployments.hatsAdaptor.getHatsData();

        assertEq(modifiedData.playerHatIds.length, 1, "new player id not removed");
        assertEq(modifiedData.characterHatIds.length, 1, "new character id not removed");
    }
}
