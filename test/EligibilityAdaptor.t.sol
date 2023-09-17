// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
pragma abicoder v2;

//solhint-disable

import "forge-std/Test.sol";
import "../src/implementations/ItemsImplementation.sol";
import "./helpers/SetUp.sol";
import "../src/lib/Structs.sol";
import "../src/lib/Errors.sol";

contract EligibilityAdaptorTest is Test, SetUp {
    function testSupportsInterface() public {
        eligibility.supportsInterface(0x01ffc9a7);
    }
}
