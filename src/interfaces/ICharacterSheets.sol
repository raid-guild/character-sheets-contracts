// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
pragma abicoder v2;

interface ICharacterSheets {
    function hasRole(bytes32 role, address account) external view returns (bool);
}
