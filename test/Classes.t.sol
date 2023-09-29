// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
pragma abicoder v2;

//solhint-disable

import "forge-std/Test.sol";
import "forge-std/console2.sol";

import "../src/implementations/ClassesImplementation.sol";
import "./helpers/SetUp.sol";
import "../src/lib/Structs.sol";

contract ClassesTest is Test, SetUp {
    function testCreateClass() public {
        vm.prank(admin);
        uint256 _classId = classes.createClassType(createNewClass(true));
        Class memory _class = classes.getClass(_classId);

        assertEq(classes.totalClasses(), 2, "incorrect total classes");
        assertEq(_classId, 1, "incorrect class id");
        assertTrue(_class.claimable, "incorrect claimable");
        assertEq(_class.supply, 0);
        assertEq(classes.uri(_classId), "test_base_uri_classes/test_class_cid/", "incorrect token uri");
    }

    function testAssignClass() public {
        vm.startPrank(admin);

        uint256 classId = classes.createClassType(createNewClass(true));
        assertEq(classId, 1, "incorrect class id");

        classes.assignClass(npc1, classId);
        vm.stopPrank();

        assertEq(classes.balanceOf(npc1, classId), 1);

        //add second class
        vm.prank(admin);
        classes.assignClass(npc1, 0);

        assertEq(classes.balanceOf(npc1, 0), 1, "does not own second class");
    }

    function testRenounceClass() public {
        vm.startPrank(admin);
        uint256 classId = classes.createClassType(createNewClass(true));
        classes.assignClass(npc1, classId);
        vm.stopPrank();

        assertEq(classes.balanceOf(npc1, classId), 1, "does not own class");

        vm.prank(npc1);
        classes.renounceClass(classId);

        assertEq(classes.balanceOf(npc1, classId), 0, "Incorrect class balance");
    }

    function testRevokeClass() public {
        vm.startPrank(admin);
        uint256 classId = classes.createClassType(createNewClass(true));

        classes.assignClass(npc1, classId);
        vm.stopPrank();

        assertEq(classes.balanceOf(npc1, classId), 1, "does not own class");

        vm.prank(admin);
        classes.revokeClass(npc1, classId);

        assertEq(classes.balanceOf(npc1, classId), 0, "Incorrect class balance");
    }

    function testTransferClass() public {
        vm.prank(admin);
        classes.assignClass(npc1, 0);

        assertEq(classes.balanceOf(npc1, 0), 1, "incorrect class assignment");

        vm.prank(npc1);
        vm.expectRevert();
        classes.safeTransferFrom(npc1, player1, 0, 1, "");

        vm.prank(admin);
        dao.addMember(player2);

        vm.prank(player2);
        uint256 player2Id = characterSheets.rollCharacterSheet("test");
        assertEq(player2Id, 1, "incorrect character id");

        address npc2 = characterSheets.getCharacterSheetByCharacterId(player2Id).accountAddress;

        vm.prank(npc1);
        vm.expectRevert();
        classes.safeTransferFrom(npc1, npc2, 0, 1, "");

        vm.prank(admin);
        classes.safeTransferFrom(npc1, npc2, 0, 1, "");

        assertEq(classes.balanceOf(npc2, 0), 1, "incorrect class assignment");
        assertEq(classes.balanceOf(npc1, 0), 0, "incorrect class assignment");
    }

    function testClaimClass() public {
        vm.prank(npc1);
        classes.claimClass(0);

        assertEq(classes.balanceOf(npc1, 0), 1, "incorrect token balance");
    }

    function testLevelClass() public {
        vm.prank(npc1);
        classes.claimClass(0);

        vm.prank(admin);
        experience.dropExp(npc1, 300 * 10 ** 18);

        vm.prank(admin);
        classes.levelClass(npc1, 0);

        assertEq(experience.balanceOf(npc1), 0, "incorrect exp balance");
        assertEq(classes.balanceOf(npc1, 0), 2, "incorrect class level");
    }

    function testFuzz_DeLevelClass(uint256 numberOfLevels) public {
        vm.assume(numberOfLevels < 20);
        uint256 baseExpAmount = 400000 * 10 ** 18;
        //give exp to npc to level
        vm.prank(admin);
        experience.dropExp(npc1, baseExpAmount);

        assertEq(experience.balanceOf(npc1), baseExpAmount);

        // give class to npc1

        vm.startPrank(admin);
        classes.assignClass(npc1, 0);

        assertEq(classes.balanceOf(npc1, 0), 1);

        // level class

        for (uint256 i; i < numberOfLevels; i++) {
            classes.levelClass(npc1, 0);
        }

        assertEq(classes.balanceOf(npc1, 0), numberOfLevels + 1, "incorrect level");

        // check that the remaining exp is correct
        assertEq(
            experience.balanceOf(npc1),
            baseExpAmount - classLevels.getExpForLevel(numberOfLevels),
            "incorrect remaining exp"
        );
        vm.stopPrank();
        // delevel class to reclaim exp

        vm.prank(npc1);
        classes.deLevelClass(0, numberOfLevels);

        //check balances
        assertEq(classes.balanceOf(npc1, 0), 1, "incorrect final balance");
        assertEq(experience.balanceOf(npc1), baseExpAmount, "incorrect returned exp");
    }
}
