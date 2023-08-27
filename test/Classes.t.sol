// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
pragma abicoder v2;

//solhint-disable

import "forge-std/Test.sol";
import "../src/implementations/ClassesImplementation.sol";
import "./helpers/SetUp.sol";
import "../src/lib/Structs.sol";

contract ClassesTest is Test, SetUp {
    function testCreateClass() public {
        vm.prank(admin);
        uint256 _classId = classes.createClassType(createNewClass("Ballerina"));
        (uint256 classId, string memory name, uint256 supply, string memory cid) = classes.classes(_classId);

        assertEq(classes.totalClasses(), 2);
        assertEq(_classId, 2);
        assertEq(classId, 2);
        assertEq(keccak256(abi.encode(name)), keccak256(abi.encode("Ballerina")));
        assertEq(supply, 0);
        assertEq(keccak256(abi.encode(cid)), keccak256(abi.encode("test_class_cid/")));
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

        assertEq(classes.balanceOf(secondPlayer.ERC6551TokenAddress, 2), 1, "does not own second class");
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
        assertEq(classes.balanceOf(player.ERC6551TokenAddress, allClasses[0].tokenId), 1, "incorrect balance");
        assertEq(classes.balanceOf(player.ERC6551TokenAddress, allClasses[1].tokenId), 1, "incorrect balance token 2");
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

        assertEq(classes.balanceOf(sheet.ERC6551TokenAddress, tokenId), 1, "Incorrect class balance");
    }

    function testFindClassByName() public {
        uint256 classId = classes.findClassByName("test_class");
        assertEq(classId, 1);

        vm.expectRevert();
        classes.findClassByName("no_class");
    }
}
