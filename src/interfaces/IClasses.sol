// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
pragma abicoder v2;

interface IClasses {
    function balanceOf(address account, uint256 classId) external returns (uint256);
}
