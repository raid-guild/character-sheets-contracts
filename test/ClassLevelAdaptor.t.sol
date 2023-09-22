// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
pragma abicoder v2;

//solhint-disable

import "forge-std/Test.sol";

import "../src/implementations/ItemsImplementation.sol";
import "../src/lib/Structs.sol";
import "../src/lib/Errors.sol";
import "./helpers/SetUp.sol";

contract ClassLevelAdaptorTest is Test, SetUp {
    function testSupportsInterface() public {
        assertTrue(classLevels.supportsInterface(0x01ffc9a7));
    }

    function testLevelRequirementsMet() public {
        vm.expectRevert();
        vm.startPrank(npc1);
        classLevels.levelRequirementsMet(npc1, 1);

        classes.claimClass(1);
        assertFalse(classLevels.levelRequirementsMet(npc1, 1));
        vm.stopPrank();

        vm.prank(admin);
        experience.dropExp(npc1, 301);

        assertEq(experience.balanceOf(npc1), 301, "incorrect exp amount");

        vm.prank(npc1);

        assertTrue(classLevels.levelRequirementsMet(npc1, 1));
    }
}
