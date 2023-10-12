// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
pragma abicoder v2;

//solhint-disable

import "forge-std/Test.sol";

import "../src/implementations/ItemsImplementation.sol";
import "../src/lib/Structs.sol";
import "../src/lib/Errors.sol";
import "./helpers/SetUp.sol";

contract ExperienceTest is Test, SetUp {
    function testExperienceDeployment() public {
        assertEq(address(experience), storedCreated.experience, "Incorrect Experience Address");
        // assertEq(experience.characterSheets(), storedCreated.characterSheets, "incorrect character sheets address");
        // assertEq(experience.itemsContract(), stored.createdItems, "incorrect items address");

        vm.prank(admin);
        vm.expectRevert();
        experience.initialize(address(0));
    }

    function testGiveExp() public {
        //revert if called by anything but items or character sheets contract
        vm.prank(address(classes));
        experience.giveExp(npc1, 100);
        assertEq(experience.balanceOf(npc1), 100, "incorrect balance");

        vm.prank(address(classes));
        experience.giveExp(npc1, 100);

        assertEq(experience.balanceOf(npc1), 200, "incorrect balance");

        vm.prank(player1);
        vm.expectRevert();
        experience.giveExp(npc1, 100);
    }

    function testDropExp() public {
        //revert if not called by dm

        vm.prank(player1);
        vm.expectRevert();
        experience.dropExp(npc1, 100);

        //suceed if calld by dm
        vm.prank(admin);
        experience.dropExp(npc1, 100);
        assertEq(experience.balanceOf(npc1), 100, "incorrect balance");
    }

    function testRevokeExp() public {
        //drop exp to npc
        vm.prank(admin);
        experience.dropExp(npc1, 100);
        assertEq(experience.balanceOf(npc1), 100, "incorrect balance");
        //revert if not called by dm
        vm.prank(player1);
        vm.expectRevert();
        experience.revokeExp(npc1, 100);

        //suceed if calld by dm
        vm.prank(admin);
        experience.revokeExp(npc1, 100);
        assertEq(experience.balanceOf(npc1), 0, "incorrect balance");
    }

    function testBurnExp() public {
        vm.prank(admin);
        experience.dropExp(npc1, 100);
        assertEq(experience.balanceOf(npc1), 100, "incorrect balance");
        //revert if not called by another contract
        vm.prank(player1);
        vm.expectRevert();
        experience.burnExp(npc1, 100);

        //suceed if calld by another contract
        vm.prank(address(classes));
        experience.burnExp(npc1, 99);
        assertEq(experience.balanceOf(npc1), 1, "incorrect balance");
    }
}
