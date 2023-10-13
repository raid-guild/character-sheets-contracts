// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface ICharacterEligibilityAdaptor {
    /// @notice Returns whether or not an address is eligible to roll a character sheet
    /// @dev this checks the adaptor contract which must implement the correct erc165 interface in order to determin eligibility
    /// @param account address of the account being checked
    /// @return bool  elegibility

    function isEligible(address account) external view returns (bool);
}
