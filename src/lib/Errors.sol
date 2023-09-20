// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

abstract contract Errors {
    error VariableNotSet();
    error EligibilityError();
    error CharacterError();
    error PlayerError();
    error InventoryError();
    error OwnershipError();
    error InvalidToken();
    error ClaimableError();
    error TransferError();
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
    error CallerNotApproved();
    error SoulboundToken();
    error RequirementNotMet();
}
