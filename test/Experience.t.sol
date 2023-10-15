// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
pragma abicoder v2;

//solhint-disable

import "forge-std/Test.sol";

import "../src/implementations/ItemsImplementation.sol";
import "../src/lib/Structs.sol";
import "../src/lib/Errors.sol";
import "./setup/SetUp.sol";

contract ExperienceTest is SetUp {
    function testExperienceDeployment() public {
        vm.prank(accounts.admin);
        vm.expectRevert();
        deployments.experience.initialize(address(0));
    }

    function testGiveExp() public {
        //revert if called by anything but items or character sheets contract
        vm.prank(address(deployments.classes));
        deployments.experience.giveExp(accounts.character1, 100);
        assertEq(deployments.experience.balanceOf(accounts.character1), 100, "incorrect balance");

        vm.prank(address(deployments.classes));
        deployments.experience.giveExp(accounts.character1, 100);

        assertEq(deployments.experience.balanceOf(accounts.character1), 200, "incorrect balance");

        vm.prank(accounts.player1);
        vm.expectRevert();
        deployments.experience.giveExp(accounts.character1, 100);
    }

    function testDropExp() public {
        //revert if not called by dm

        vm.prank(accounts.player1);
        vm.expectRevert(Errors.DungeonMasterOnly.selector);
        deployments.experience.dropExp(accounts.character1, 100);

        //suceed if calld by dm
        vm.prank(accounts.dungeonMaster);
        deployments.experience.dropExp(accounts.character1, 100);
        assertEq(deployments.experience.balanceOf(accounts.character1), 100, "incorrect balance");
    }

    function testRevokeExp() public {
        //drop exp to npc
        vm.prank(accounts.dungeonMaster);
        deployments.experience.dropExp(accounts.character1, 100);
        assertEq(deployments.experience.balanceOf(accounts.character1), 100, "incorrect balance");
        //revert if not called by dm
        vm.prank(accounts.player1);
        vm.expectRevert();
        deployments.experience.revokeExp(accounts.character1, 100);

        //suceed if called by dm
        vm.prank(accounts.dungeonMaster);
        deployments.experience.revokeExp(accounts.character1, 100);
        assertEq(deployments.experience.balanceOf(accounts.character1), 0, "incorrect balance");
    }

    function testBurnExp() public {
        vm.prank(accounts.dungeonMaster);
        deployments.experience.dropExp(accounts.character1, 100);
        assertEq(deployments.experience.balanceOf(accounts.character1), 100, "incorrect balance");
        //revert if not called by another contract
        vm.prank(accounts.player1);
        vm.expectRevert();
        deployments.experience.burnExp(accounts.character1, 100);

        //suceed if calld by another contract
        vm.prank(address(deployments.classes));
        deployments.experience.burnExp(accounts.character1, 99);
        assertEq(deployments.experience.balanceOf(accounts.character1), 1, "incorrect balance");
    }
}
