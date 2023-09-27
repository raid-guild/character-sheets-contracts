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
        (uint256 classId, uint256 supply, bool claimable, string memory cid) = classes.classes(_classId);

        assertEq(classes.totalClasses(), 2);
        assertEq(claimable, true, "incorrect claimable");
        assertEq(_classId, 2);
        assertEq(classId, 2);
        assertTrue(claimable, "incorrect claimable");
        assertEq(supply, 0);
        assertEq(keccak256(abi.encode(cid)), keccak256(abi.encode("test_class_cid/")));
        assertEq(classes.uri(classId), "test_base_uri_classes/test_class_cid/", "incorrect token uri");
    }

    function testBatchCreateClass() public {
        vm.prank(admin);
        bytes[] memory _classes = new bytes[](2);
        _classes[0] = createNewClass(true);
        _classes[1] = createNewClass(false);
        uint256[] memory _classIds = classes.batchCreateClassType(_classes);

        assertEq(_classIds.length, 2, "incorrect length");

        assertEq(classes.totalClasses(), 3, "Incorrect number of classes");
        (uint256 classId, uint256 supply, bool claimable, string memory cid) = classes.classes(_classIds[0]);

        assertEq(classes.totalClasses(), 3, "incorrect total classes");
        assertEq(_classIds[0], 2, "incorrect class id");
        assertEq(classId, 2, "incorrect class id");
        assertTrue(claimable, "incorrect claimable");
        assertEq(supply, 0, "incorrect supply");
        assertEq(keccak256(abi.encode(cid)), keccak256(abi.encode("test_class_cid/")), "incorrect cid");
        assertEq(classes.uri(classId), "test_base_uri_classes/test_class_cid/", "incorrect token uri");

        (classId, supply, claimable, cid) = classes.classes(_classIds[1]);
        assertEq(_classIds[1], 3, "incorrect class id 2");
        assertEq(classId, 3, "incorrect class id 2");
        assertFalse(claimable, "incorrect clamable 2");
        assertEq(supply, 0, "incorrect supply");
        assertEq(keccak256(abi.encode(cid)), keccak256(abi.encode("test_class_cid/")), "incorrect cid");
        assertEq(classes.uri(classId), "test_base_uri_classes/test_class_cid/", "incorrect token uri");
    }

    function testAssignClass() public {
        uint256 playerId = characterSheets.memberAddressToTokenId(player1);
        vm.startPrank(admin);

        uint256 classId = classes.createClassType(createNewClass(true));

        classes.assignClass(npc1, classId);
        vm.stopPrank();

        characterSheets.getCharacterSheetByCharacterId(playerId);

        assertEq(classes.balanceOf(npc1, classId), 1);

        //add second class
        vm.prank(admin);
        classes.assignClass(npc1, 1);

        CharacterSheet memory secondPlayer = characterSheets.getCharacterSheetByCharacterId(playerId);

        assertEq(classes.balanceOf(secondPlayer.erc6551TokenAddress, 2), 1, "does not own second class");
    }

    function testAssignClasses() public {
        uint256 playerId = characterSheets.memberAddressToTokenId(player1);
        vm.startPrank(admin);

        classes.createClassType(createNewClass(true));
        Class[] memory allClasses = classes.getAllClasses();

        uint256[] memory classesArr = new uint256[](2);
        classesArr[0] = allClasses[0].tokenId;
        classesArr[1] = allClasses[1].tokenId;
        classes.assignClasses(npc1, classesArr);
        vm.stopPrank();
        CharacterSheet memory player = characterSheets.getCharacterSheetByCharacterId(playerId);
        assertEq(classes.balanceOf(player.erc6551TokenAddress, allClasses[0].tokenId), 1, "incorrect balance");
        assertEq(classes.balanceOf(player.erc6551TokenAddress, allClasses[1].tokenId), 1, "incorrect balance token 2");
    }

    function testRevokeClass() public {
        uint256 playerId = characterSheets.memberAddressToTokenId(player1);

        vm.startPrank(admin);
        uint256 tokenId = classes.createClassType(createNewClass(true));

        Class[] memory allClasses = classes.getAllClasses();

        uint256[] memory classesArr = new uint256[](2);
        classesArr[0] = allClasses[0].tokenId;
        classesArr[1] = allClasses[1].tokenId;

        classes.assignClasses(npc1, classesArr);
        vm.stopPrank();

        vm.prank(npc1);
        classes.revokeClass(npc1, allClasses[0].tokenId);

        CharacterSheet memory sheet = characterSheets.getCharacterSheetByCharacterId(playerId);

        assertEq(classes.balanceOf(sheet.erc6551TokenAddress, tokenId), 1, "Incorrect class balance");
    }

    function testTransferClass() public {
        vm.prank(admin);
        classes.assignClass(npc1, 1);

        assertEq(classes.balanceOf(npc1, 1), 1, "incorrect class assignment");

        vm.prank(npc1);
        vm.expectRevert();
        classes.safeTransferFrom(npc1, player1, 1, 1, "");

        vm.prank(admin);
        classes.safeTransferFrom(npc1, player1, 1, 1, "");

        assertEq(classes.balanceOf(player1, 1), 1, "incorrect class assignment");
        assertEq(classes.balanceOf(npc1, 1), 0, "incorrect class assignment");
    }

    function testClaimClass() public {
        vm.prank(npc1);
        classes.claimClass(1);

        assertEq(classes.balanceOf(npc1, 1), 1, "incorrect token balance");
    }

    function testLevelClass() public {
        vm.prank(npc1);
        classes.claimClass(1);

        vm.prank(admin);
        experience.dropExp(npc1, 300 * 10 ** 18);

        vm.prank(admin);
        classes.levelClass(npc1, 1);

        assertEq(experience.balanceOf(npc1), 0, "incorrect exp balance");
        assertEq(classes.balanceOf(npc1, 1), 2, "incorrect class level");
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
        classes.assignClass(npc1, 1);

        assertEq(classes.balanceOf(npc1, 1), 1);

        // level class

        for (uint256 i; i < numberOfLevels; i++) {
            classes.levelClass(npc1, 1);
        }

        assertEq(classes.balanceOf(npc1, 1), numberOfLevels + 1, "incorrect level");

        // check that the remaining exp is correct
        assertEq(
            experience.balanceOf(npc1),
            baseExpAmount - classLevels.getExpForLevel(numberOfLevels),
            "incorrect remaining exp"
        );
        vm.stopPrank();
        // delevel class to reclaim exp

        vm.prank(npc1);
        classes.deLevelClass(1, numberOfLevels);

        //check balances
        assertEq(classes.balanceOf(npc1, 1), 1, "incorrect final balance");
        assertEq(experience.balanceOf(npc1), baseExpAmount, "incorrect returned exp");
    }
}
