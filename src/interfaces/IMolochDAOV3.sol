pragma solidity ^0.8.20;

// SPDX-License-Identifier: MIT

interface IMolochDAOV3 {
    // get shares token of v3 dao
    function sharesToken() external view returns (address);
}
