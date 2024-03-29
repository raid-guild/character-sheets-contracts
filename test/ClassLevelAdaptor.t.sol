// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
pragma abicoder v2;

//solhint-disable

import "forge-std/Test.sol";

import "../src/implementations/ItemsImplementation.sol";
import "../src/lib/Structs.sol";
import "../src/lib/Errors.sol";
import "./setup/SetUp.t.sol";

contract ClassLevelAdaptorTest is SetUp {
    function testSupportsInterface() public view {
        assertTrue(deployments.classLevels.supportsInterface(0x01ffc9a7));
    }

    function testFuzz_GetCurrentLevel(uint256 exp) public view {
        exp = bound(exp, 0, 455000);
        uint256 currentLevel = deployments.classLevels.getCurrentLevel(exp);
        uint256 desiredLevelExp = deployments.classLevels.getExpForLevel(currentLevel - 1);
        bool accurateLevel;
        if (currentLevel < 20) {
            uint256 desiredNextLevelExp = deployments.classLevels.getExpForLevel(currentLevel);
            accurateLevel = desiredLevelExp <= exp && desiredNextLevelExp > exp;
        } else {
            accurateLevel = desiredLevelExp <= exp;
        }

        assertTrue(accurateLevel, "wrong level given");
    }
}
