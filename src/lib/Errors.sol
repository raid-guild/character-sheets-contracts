// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

abstract contract Errors {
    error VariableNotSet();
    error TokenBalanceError();
    error EligibilityError();
    error CharacterError();
    error PlayerError();
    error InventoryError();
    error OwnershipError();
    error InvalidToken();
    error ClaimableError();
    error CraftableError();
    error TransferError();
    error DuplicateError();
    error GameMasterOnly();
    error PlayerOnly();
    error AdminOnly();
    error CharacterOnly();
    error ClassError();
    error RequirementError();
    error ItemError();
    error LengthMismatch();

    error Jailed();
    error InsufficientBalance();
    error CallerNotApproved();
    error SoulboundToken();
    error RequirementNotMet();

    //merkle proof erros
    error CannotClaim(uint256);
    error InvalidProof();
    // CharacterAccount.sol
    error InvalidSigner();
    error InvalidOperation();

    // Common
    error NotInitialized();

    // ClassLevel
    error InvalidClassLevel();

    // Factory
    error UnsupportedInterface();

    error MustRefundFullReceiptAmount(uint256 amountRequired);
}
