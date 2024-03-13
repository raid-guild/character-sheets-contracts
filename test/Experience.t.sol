// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
pragma abicoder v2;

import "forge-std/Test.sol";

import "../src/implementations/ItemsImplementation.sol";
import "../src/lib/Structs.sol";
import "../src/lib/Errors.sol";
import "./setup/SetUp.t.sol";

contract ExperienceTest is SetUp {
    function testExperienceDeployment() public {
        vm.prank(accounts.admin);
        vm.expectRevert();
        deployments.experience.initialize(address(0));
    }

    function testDropExp() public {
        //revert if not called by dm or contract
        vm.prank(accounts.player1);
        vm.expectRevert(Errors.CallerNotApproved.selector);
        deployments.experience.dropExp(accounts.character1, 100);

        //suceed if calld by dm
        vm.prank(accounts.gameMaster);
        deployments.experience.dropExp(accounts.character1, 100);
        assertEq(deployments.experience.balanceOf(accounts.character1), 100, "incorrect balance");
        //suceed if calld by contract
        vm.prank(address(deployments.items));
        deployments.experience.dropExp(accounts.character1, 100);
        assertEq(deployments.experience.balanceOf(accounts.character1), 200, "incorrect balance");
    }

    function testBurnExp() public {
        vm.prank(accounts.gameMaster);
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
