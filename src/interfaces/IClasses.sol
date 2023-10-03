// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Class} from "../lib/Structs.sol";

interface IClasses {
    function getClass(uint256 classId) external view returns (Class memory);
}
