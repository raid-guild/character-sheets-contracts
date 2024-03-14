// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
pragma abicoder v2;

import "forge-std/Test.sol";
import "forge-std/console2.sol";

import "../src/implementations/ClassesImplementation.sol";
import "./setup/SetUp.t.sol";
import "../src/lib/Structs.sol";

contract ClassesTest is SetUp {
    function testCreateClass() public {
        vm.prank(accounts.gameMaster);
        uint256 _classId = deployments.classes.createClassType(createNewClass(true));
        Class memory _class = deployments.classes.getClass(_classId);

        assertEq(deployments.classes.totalClasses(), 3, "incorrect total classes");
        assertEq(_classId, 3, "incorrect class id");
        assertTrue(_class.claimable, "incorrect claimable");
        assertEq(_class.supply, 0);
        assertEq(deployments.classes.uri(_classId), "test_base_uri_classes/test_class_cid/", "incorrect token uri");
    }

    function testAssignClass() public {
        vm.startPrank(accounts.gameMaster);

        uint256 newClassId = deployments.classes.createClassType(createNewClass(true));
        assertEq(newClassId, 3, "incorrect class id");

        deployments.classes.assignClass(accounts.character1, newClassId);
        vm.stopPrank();

        assertEq(deployments.classes.balanceOf(accounts.character1, newClassId), 1, "new class not assigned");

        //add second class
        vm.prank(accounts.gameMaster);
        deployments.classes.assignClass(accounts.character1, 1);

        assertEq(deployments.classes.balanceOf(accounts.character1, 1), 1, "does not own second class");
    }

    function testRenounceClass() public {
        vm.startPrank(accounts.gameMaster);
        uint256 newClassId = deployments.classes.createClassType(createNewClass(true));
        deployments.classes.assignClass(accounts.character1, newClassId);
        vm.stopPrank();

        assertEq(deployments.classes.balanceOf(accounts.character1, newClassId), 1, "does not own class");

        vm.prank(accounts.character1);
        deployments.classes.renounceClass(newClassId);

        assertEq(deployments.classes.balanceOf(accounts.character1, newClassId), 0, "Incorrect class balance");
    }

    function testRevokeClass() public {
        vm.startPrank(accounts.gameMaster);
        uint256 newClassId = deployments.classes.createClassType(createNewClass(true));

        deployments.classes.assignClass(accounts.character1, newClassId);
        vm.stopPrank();

        assertEq(deployments.classes.balanceOf(accounts.character1, newClassId), 1, "does not own class");

        vm.prank(accounts.gameMaster);
        deployments.classes.revokeClass(accounts.character1, newClassId);

        assertEq(deployments.classes.balanceOf(accounts.character1, newClassId), 0, "Incorrect class balance");
    }

    function testTransferClass() public {
        vm.prank(accounts.gameMaster);
        deployments.classes.assignClass(accounts.character1, 0);

        assertEq(deployments.classes.balanceOf(accounts.character1, 0), 1, "incorrect class assignment");

        vm.prank(accounts.character1);
        vm.expectRevert();
        deployments.classes.safeTransferFrom(accounts.character1, accounts.character2, 0, 1, "");

        vm.prank(accounts.gameMaster);
        dao.addMember(accounts.rando);

        vm.prank(accounts.rando);
        uint256 randoId = deployments.characterSheets.rollCharacterSheet("test");
        assertEq(randoId, 2, "incorrect character id");

        address character3 = deployments.characterSheets.getCharacterSheetByCharacterId(randoId).accountAddress;

        vm.prank(accounts.character1);
        vm.expectRevert();
        deployments.classes.safeTransferFrom(accounts.character1, character3, 0, 1, "");

        vm.prank(accounts.gameMaster);
        deployments.classes.safeTransferFrom(accounts.character1, character3, 0, 1, "");

        assertEq(deployments.classes.balanceOf(character3, 0), 1, "incorrect class assignment");
        assertEq(deployments.classes.balanceOf(accounts.character1, 0), 0, "incorrect class assignment");
    }

    function testClaimClass() public {
        vm.prank(accounts.character1);
        deployments.classes.claimClass(classData.classIdClaimable);

        assertEq(
            deployments.classes.balanceOf(accounts.character1, classData.classIdClaimable), 1, "incorrect token balance"
        );
    }

    function testClassExp() public {
        vm.startPrank(accounts.gameMaster);
        deployments.classes.assignClass(accounts.character1, 1);
        vm.stopPrank();

        uint256 generalExp = deployments.experience.balanceOf(accounts.character1);

        uint256 classExp = 100;
        vm.prank(accounts.gameMaster);
        deployments.classes.giveClassExp(accounts.character1, 1, classExp);

        assertEq(deployments.classes.classExp(accounts.character1, 1), classExp, "incorrect class exp");
        assertEq(deployments.experience.balanceOf(accounts.character1), generalExp + classExp, "incorrect general exp");

        // revoke
        vm.prank(accounts.gameMaster);
        deployments.classes.revokeClassExp(accounts.character1, 1, classExp);

        assertEq(deployments.classes.classExp(accounts.character1, 1), 0, "incorrect class exp");
        assertEq(deployments.experience.balanceOf(accounts.character1), generalExp, "incorrect general exp");
    }

    function testFuzz_BalanceOf(uint256 _classExp) public {
        vm.assume(_classExp < 1_000_000);

        //give class & class exp;
        vm.startPrank(accounts.gameMaster);
        deployments.classes.assignClass(accounts.character1, 1);
        deployments.classes.giveClassExp(accounts.character1, 1, _classExp);
        vm.stopPrank();
        uint256 desiredLevel = deployments.classLevels.getCurrentLevel(_classExp);
        if (_classExp < 300) {
            assertEq(desiredLevel, 1, "incorrect level balance");
        } else {
            //check balanceOf;
            uint256 balance = deployments.classes.balanceOf(accounts.character1, 1);
            assertEq(desiredLevel, balance, "incorrect level returned");
        }
    }
}
