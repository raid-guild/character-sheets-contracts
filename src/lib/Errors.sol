// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

abstract contract Errors {
    error VariableNotSet();
    error DaoError();
    error CharacterError();
    error PlayerError();
    error InventoryError();
    error OwnershipError();
    error DuplicateError();
    error DungeonMasterOnly();
    error PlayerOnly();
    error CharacterOnly();
    error ClassError();
    error RequirementError();
    error ItemError();
    error LengthMismatch();
    error InvalidProof();
    error Jailed();
    error InsufficientBalance();
}
