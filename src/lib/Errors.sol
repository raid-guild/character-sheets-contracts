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

    error CraftItemsError();
    error CraftItemError();

    error Jailed();
    error InsufficientBalance();
    error CallerNotApproved();
    error SoulboundToken();
    error RequirementNotMet();

    error ExceedsDistribution();

    //merkle proof erros
    error InvalidProof();

    // CharacterAccount.sol
    error InvalidSigner();
    error InvalidOperation();

    error DeletedItem();

    // Common
    error NotInitialized();

    // ClassLevel
    error InvalidClassLevel();

    // Factory
    error UnsupportedInterface();

    error MustRefundFullReceiptAmount(uint256 amountRequired);

    // Requirement Tree
    error InvalidOperator();
    error InvalidNilOperator();
    error InvalidAndOperator();
    error InvalidOrOperator();
    error InvalidNotOperator();
}
