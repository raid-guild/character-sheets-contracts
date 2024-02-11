// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IImplementationAddressStorage {
    function characterSheetsImplementation() external view returns (address);

    function itemsImplementation() external view returns (address);

    function classesImplementation() external view returns (address);

    function itemsManagerImplementation() external view returns (address);

    function experienceImplementation() external view returns (address);

    function erc6551Registry() external view returns (address);

    function erc6551AccountImplementation() external view returns (address);

    function molochV2EligibilityAdaptorImplementation() external view returns (address);

    function molochV3EligibilityAdaptorImplementation() external view returns (address);

    function classLevelAdaptorImplementation() external view returns (address);

    function hatsAdaptorImplementation() external view returns (address);

    function cloneAddressStorage() external view returns (address);

    function hatsContract() external view returns (address);

    function hatsModuleFactory() external view returns (address);

    function addressHatsEligibilityModule() external view returns (address);

    function erc721HatsEligibilityModule() external view returns (address);

    function erc6551HatsEligibilityModule() external view returns (address);
    function MultiERC6551HatsEligibilityModule() external view returns (address);
}
