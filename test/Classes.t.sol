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
        uint256 _classId = classes.createClassType(createNewClass("Ballerina"));
        (uint256 classId, string memory name, uint256 supply, bool claimable, string memory cid) =
            classes.classes(_classId);

        assertEq(classes.totalClasses(), 2);
        assertEq(claimable, true, "incorrect claimable");
        assertEq(_classId, 2);
        assertEq(classId, 2);
        assertEq(keccak256(abi.encode(name)), keccak256(abi.encode("Ballerina")));
        assertEq(supply, 0);
        assertEq(keccak256(abi.encode(cid)), keccak256(abi.encode("test_class_cid/")));
        assertEq(classes.uri(classId), "test_base_uri_classes/test_class_cid/", "incorrect token uri");
    }

    function testBatchCreateClass() public {
        vm.prank(admin);
        bytes[] memory _classes = new bytes[](2);
        _classes[0] = createNewClass("Ballerina1");
        _classes[1] = createNewClass("Ballerina2");
        uint256[] memory _classIds = classes.batchCreateClassType(_classes);

        assertEq(_classIds.length, 2, "incorrect length");

        (uint256 classId, string memory name, uint256 supply, bool claimable, string memory cid) =
            classes.classes(_classIds[0]);

        assertEq(classes.totalClasses(), 3, "incorrect total classes");
        assertEq(_classIds[0], 2, "incorrect class id");
        assertEq(classId, 2, "incorrect class id");
        assertEq(keccak256(abi.encode(name)), keccak256(abi.encode("Ballerina1")), "incorrect class name");
        assertEq(supply, 0, "incorrect supply");
        assertEq(keccak256(abi.encode(cid)), keccak256(abi.encode("test_class_cid/")), "incorrect cid");
        assertEq(classes.uri(classId), "test_base_uri_classes/test_class_cid/", "incorrect token uri");

        (classId, name, supply, claimable, cid) = classes.classes(_classIds[1]);
        assertEq(claimable, true, "incorrect claimable");
        assertEq(_classIds[1], 3, "incorrect class id");
        assertEq(classId, 3, "incorrect class id");
        assertEq(keccak256(abi.encode(name)), keccak256(abi.encode("Ballerina2")), "incorrect class name");
        assertEq(supply, 0, "incorrect supply");
        assertEq(keccak256(abi.encode(cid)), keccak256(abi.encode("test_class_cid/")), "incorrect cid");
        assertEq(classes.uri(classId), "test_base_uri_classes/test_class_cid/", "incorrect token uri");
    }

    function testAssignClass() public {
        uint256 playerId = characterSheets.memberAddressToTokenId(player1);
        vm.startPrank(admin);

        uint256 classId = classes.createClassType(createNewClass("Ballerina"));

        classes.assignClass(playerId, classId);
        vm.stopPrank();

        characterSheets.getCharacterSheetByCharacterId(playerId);

        assertEq(classes.balanceOf(npc1, classId), 1);

        //add second class
        vm.prank(admin);
        classes.assignClass(playerId, 1);

        CharacterSheet memory secondPlayer = characterSheets.getCharacterSheetByCharacterId(playerId);

        assertEq(classes.balanceOf(secondPlayer.erc6551TokenAddress, 2), 1, "does not own second class");
    }

    function testAssignClasses() public {
        uint256 playerId = characterSheets.memberAddressToTokenId(player1);
        vm.startPrank(admin);

        classes.createClassType(createNewClass("Ballerina"));
        Class[] memory allClasses = classes.getAllClasses();

        uint256[] memory classesArr = new uint256[](2);
        classesArr[0] = allClasses[0].tokenId;
        classesArr[1] = allClasses[1].tokenId;
        classes.assignClasses(playerId, classesArr);
        vm.stopPrank();
        CharacterSheet memory player = characterSheets.getCharacterSheetByCharacterId(playerId);
        assertEq(classes.balanceOf(player.erc6551TokenAddress, allClasses[0].tokenId), 1, "incorrect balance");
        assertEq(classes.balanceOf(player.erc6551TokenAddress, allClasses[1].tokenId), 1, "incorrect balance token 2");
    }

    function testRevokeClass() public {
        uint256 playerId = characterSheets.memberAddressToTokenId(player1);

        vm.startPrank(admin);
        uint256 tokenId = classes.createClassType(createNewClass("Ballerina"));

        Class[] memory allClasses = classes.getAllClasses();

        uint256[] memory classesArr = new uint256[](2);
        classesArr[0] = allClasses[0].tokenId;
        classesArr[1] = allClasses[1].tokenId;

        classes.assignClasses(playerId, classesArr);
        vm.stopPrank();

        vm.prank(player1);
        classes.revokeClass(playerId, allClasses[0].tokenId);

        CharacterSheet memory sheet = characterSheets.getCharacterSheetByCharacterId(playerId);

        assertEq(classes.balanceOf(sheet.erc6551TokenAddress, tokenId), 1, "Incorrect class balance");
    }

    function testFindClassByName() public {
        uint256 classId = classes.findClassByName("test_class");
        assertEq(classId, 1);

        vm.expectRevert();
        classes.findClassByName("no_class");
    }

    function testTransferClass() public {
        vm.prank(admin);
        classes.assignClass(1, 1);

        assertEq(classes.balanceOf(npc1, 1), 1, "incorrect class assignment");

        vm.prank(npc1);
        vm.expectRevert();
        classes.safeTransferFrom(npc1, player1, 1, 1, "");

        vm.prank(admin);
        classes.safeTransferFrom(npc1, player1, 1, 1, "");

        assertEq(classes.balanceOf(player1, 1), 1, "incorrect class assignment");
        assertEq(classes.balanceOf(npc1, 1), 0, "incorrect class assignment");
    }
}
