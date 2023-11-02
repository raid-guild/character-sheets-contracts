// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
pragma abicoder v2;

//solhint-disable

import "forge-std/Test.sol";

import "../src/implementations/ItemsImplementation.sol";
import "../src/lib/Structs.sol";
import "../src/lib/Errors.sol";
import "./setup/SetUp.sol";

contract ClassLevelAdaptorTest is SetUp {
    function testSupportsInterface() public {
        assertTrue(deployments.classLevels.supportsInterface(0x01ffc9a7));
    }

    function testLevelRequirementsMet() public {
        vm.expectRevert();
        vm.startPrank(accounts.character1);
        deployments.classLevels.levelRequirementsMet(accounts.character1, 1);

        deployments.classes.claimClass(0);
        assertFalse(deployments.classLevels.levelRequirementsMet(accounts.character1, 0), "should not be met");
        vm.stopPrank();
        uint256 expAmount = 301 * 10 ** 18;
        vm.prank(accounts.gameMaster);
        deployments.experience.dropExp(accounts.character1, expAmount);

        assertEq(deployments.experience.balanceOf(accounts.character1), expAmount, "incorrect exp amount");

        vm.prank(accounts.character1);

        assertTrue(deployments.classLevels.levelRequirementsMet(accounts.character1, 0), "should be met");
    }
}
