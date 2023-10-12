// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
pragma abicoder v2;

import "forge-std/Test.sol";

import "../src/lib/Structs.sol";
import {Errors} from "../src/lib/Errors.sol";
import {SetUp} from "./helpers/SetUp.sol";
import {HatsErrors} from "hats-protocol/Interfaces/HatsErrors.sol";

contract HatsAdaptorTest is Test, SetUp {
    function testHatsAdaptorDeployment() public {
        vm.expectRevert();
        hatsAdaptor.initialize(admin, abi.encode("fake addressdata"), abi.encode("fake string data"));

        HatsData memory _hatsData = hatsAdaptor.getHatsData();

        // assertEq(
        //     _hatsData.adminHatEligibilityModuleImplementation,
        //     storedImp.adminHatEligibilityModuleImplementation,
        //     "Incorrect admin hat eligibility module"
        // );
        // assertEq(
        //     _hatsData.dungeonMasterHatEligibilityModuleImplementation,
        //     storedImp.dungeonMasterHatEligibilityModuleImplementation,
        //     "Incorrect dungeonMaster hat eligibility module"
        // );
        // assertEq(
        //     _hatsData.playerHatEligibilityModuleImplementation,
        //     storedImp.playerHatEligibilityModuleImplementation,
        //     "Incorrect player hat eligibility module"
        // );
        // assertEq(
        //     _hatsData.characterHatEligibilityModuleImplementation,
        //     storedImp.characterHatEligibilityModuleImplementation,
        //     "Incorrect character hat eligibility module"
        // );

        assertEq(hats.isAdminOfHat(admin, _hatsData.adminHatId), true, "incorrect admin hat admin");
        assertEq(
            hats.isAdminOfHat(address(hatsAdaptor), _hatsData.dungeonMasterHatId),
            true,
            "incorrect dungeon master admin"
        );
        assertEq(hats.isAdminOfHat(address(hatsAdaptor), _hatsData.playerHatId), true, "incorrect player admin");
        assertEq(hats.isAdminOfHat(address(hatsAdaptor), _hatsData.characterHatId), true, "incorrect character admin");
        assertTrue(hats.isWearerOfHat(address(hatsAdaptor), _hatsData.adminHatId), "contract not admin");
        assertTrue(hats.isWearerOfHat(admin, _hatsData.topHatId), "admin not tophat wearer");
    }

    function testMintPlayerHat() public {
        HatsData memory _hatsData = hatsAdaptor.getHatsData();
        //should revert if player is already wearing a hat
        vm.expectRevert(abi.encodeWithSelector(HatsErrors.AlreadyWearingHat.selector, player1, _hatsData.playerHatId));
        hatsAdaptor.mintPlayerHat(player1);

        //should revert if player is ineligible for hat
        vm.expectRevert(Errors.PlayerError.selector);
        hatsAdaptor.mintPlayerHat(player2);

        //should mint hat when player rolls character sheet
        dao.addMember(player2);

        vm.prank(player2);
        characterSheets.rollCharacterSheet("player2_token_uri");

        assertTrue(hats.isWearerOfHat(player2, _hatsData.playerHatId), "not wearing player hat");
    }

    function testMintCharacterHat() public {
        HatsData memory _hatsData = hatsAdaptor.getHatsData();
        //should revert if character is already wearing a character hat
        vm.expectRevert(abi.encodeWithSelector(HatsErrors.AlreadyWearingHat.selector, npc1, _hatsData.characterHatId));
        hatsAdaptor.mintCharacterHat(npc1);

        //should revert if address is ineligible for hat
        vm.expectRevert(Errors.CharacterError.selector);
        hatsAdaptor.mintCharacterHat(player2);

        //should mint character hat when sheet is rolled
        assertTrue(hats.isWearerOfHat(npc1, _hatsData.characterHatId), "not wearing character hat");
    }

    function testIsPlayer() public {
        assertTrue(hatsAdaptor.isPlayer(player1), "player one should be a player");
        assertFalse(hatsAdaptor.isPlayer(player2), "player two should not be a player.");
        assertFalse(hatsAdaptor.isPlayer(npc1), "npc1 should not be a player.");
        assertFalse(hatsAdaptor.isPlayer(admin), "admin should not be a player.");
    }

    function testIsCharacter() public {
        assertTrue(hatsAdaptor.isCharacter(npc1), "npc one should be a character");
        assertFalse(hatsAdaptor.isCharacter(player1), "player one should not be a character.");
        assertFalse(hatsAdaptor.isCharacter(admin), "admin should not be a character.");
    }

    function testIsDungeonMaster() public {
        assertTrue(hatsAdaptor.isDungeonMaster(admin), "admin should be a DungeonMaster");
        assertFalse(hatsAdaptor.isDungeonMaster(player1), "player one should not be a DungeonMaster.");
        assertFalse(hatsAdaptor.isDungeonMaster(npc1), "npc1 should not be a DungeonMaster.");
    }
}
