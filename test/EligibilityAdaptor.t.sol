// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
pragma abicoder v2;

//solhint-disable

import "forge-std/Test.sol";

import "../src/implementations/ItemsImplementation.sol";
import "../src/lib/Structs.sol";
import "../src/lib/Errors.sol";
import "./setup/SetUp.sol";

contract CharacterEligibilityAdaptorTest is SetUp {
    function testSupportsInterface() public {
        assertTrue(deployments.characterEligibility.supportsInterface(0x01ffc9a7));
    }

    function testIsEligible() public {
        //#todo finish testing
    }
}
