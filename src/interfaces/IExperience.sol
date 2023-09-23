// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
pragma abicoder v2;

interface IExperience {
    function dropExp(address to, uint256 amount) external;

    function burnExp(address account, uint256 amount) external;

    function balanceOf(address account) external view returns (uint256);
}
