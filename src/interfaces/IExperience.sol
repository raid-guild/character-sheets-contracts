// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IExperience {
    function dropExp(address to, uint256 amount) external;

    function burnExp(address account, uint256 amount) external;

    function transferFrom(address from, address to, uint256 amount) external returns (bool);

    function transfer(address to, uint256 amount) external returns (bool);

    function decimals() external pure returns (uint8);
}
