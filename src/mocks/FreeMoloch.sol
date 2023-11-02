// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IMolochDAOV2} from "../interfaces/IMolochDAOV2.sol";

contract FreeMoloch is IMolochDAOV2 {
    function members(address _member) external pure returns (Member memory m) {
        m = Member(_member, 100, 1000, true, 0, 0);
    }
}
