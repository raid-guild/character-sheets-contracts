// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IAddressEligibilityModule {
    function addEligibleAddresses(address[] calldata _addresses) external;
    function removeEligibleAddresses(address[] calldata _addresses) external;
}
