// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface IClonesAddressStorage {
    function initialize(bytes calldata encodedAddresses) external;
    function characterSheetsClone() external pure returns (address);
    function itemsClone() external pure returns (address);
    function classesClone() external pure returns (address);
    function experienceClone() external pure returns (address);
    function CharacterEligibilityAdaptorClone() external pure returns (address);
    function classLevelAdaptorClone() external pure returns (address);
    function itemsManagerClone() external pure returns (address);
    function hatsAdaptorClone() external pure returns (address);
}
