// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IClonesAddressStorage {
    function initialize(bytes calldata encodedAddresses, bytes calldata encodedAdaptorAddresses) external;

    function characterSheets() external pure returns (address);

    function items() external pure returns (address);

    function classes() external pure returns (address);

    function experience() external pure returns (address);

    function characterEligibilityAdaptor() external pure returns (address);

    function classLevelAdaptor() external pure returns (address);

    function itemsManager() external pure returns (address);

    function hatsAdaptor() external pure returns (address);
}
