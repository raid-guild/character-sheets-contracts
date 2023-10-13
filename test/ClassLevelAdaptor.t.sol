// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
pragma abicoder v2;

// //solhint-disable

// import "forge-std/Test.sol";

// import "../src/implementations/ItemsImplementation.sol";
// import "../src/lib/Structs.sol";
// import "../src/lib/Errors.sol";
// import "./helpers/SetUp.sol";
// import {Contracts} from "./helpers/Contracts.sol";

// contract ClassLevelAdaptorTest is Test, SetUp, Contracts {
//     function testSupportsInterface() public {
//         assertTrue(classLevels.supportsInterface(0x01ffc9a7));
//     }

//     function testLevelRequirementsMet() public {
//         vm.expectRevert();
//         vm.startPrank(npc1);
//         classLevels.levelRequirementsMet(npc1, 1);

//         classes.claimClass(0);
//         assertFalse(classLevels.levelRequirementsMet(npc1, 0), "should not be met");
//         vm.stopPrank();
//         uint256 expAmount = 301 * 10 ** 18;
//         vm.prank(admin);
//         experience.dropExp(npc1, expAmount);

//         assertEq(experience.balanceOf(npc1), expAmount, "incorrect exp amount");

//         vm.prank(npc1);

//         assertTrue(classLevels.levelRequirementsMet(npc1, 0), "should be met");
//     }
// }
