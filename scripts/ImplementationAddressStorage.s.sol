// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ImplementationAddressStorage} from "../src/ImplementationAddressStorage.sol";

import {BaseDeployer} from "./BaseDeployer.sol";
import {BaseFactoryExecutor} from "./BaseExecutor.sol";
import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

struct ImplementationAddresses {
    // implementation addresses
    address characterSheetsImplementation;
    address itemsImplementation;
    address itemsManagerImplementation;
    address classesImplementation;
    address erc6551Registry;
    address erc6551AccountImplementation;
    address experienceImplementation;
    address characterEligibilityAdaptorImplementation;
    address classLevelAdaptorImplementation;
    address hatsAdaptorImplementation;
    address cloneAddressStorage;
    //hats addresses
    address hatsContract;
    address hatsModuleFactory;
    //eligibility modules
    address adminHatsEligibilityModule;
    address dungeonMasterHatsEligibilityModule;
    address playerHatsEligibilityModule;
    address characterHatsEligibilityModule;
}

/**
 * function _initImplementations(bytes calldata encodedImplementationAddresses) internal {
 *         (
 *             _implementationsAddresses.characterSheetsImplementation,
 *             _implementationsAddresses.itemsImplementation,
 *             _implementationsAddresses.classesImplementation,
 *             _implementationsAddresses.experienceImplementation,
 *             _implementationsAddresses.cloneAddressStorage,
 *             _implementationsAddresses.itemsManagerImplementation,
 *             _implementationsAddresses.erc6551AccountImplementation
 *         ) = abi.decode(encodedImplementationAddresses, (address, address, address, address, address, address, address));
 *     }
 * 
 *     function _initAdaptorsAndModules(bytes calldata encodedAdaptorsAndModuleAddresses) internal {
 *         (
 *             _implementationsAddresses.adminHatsEligibilityModule,
 *             _implementationsAddresses.dungeonMasterHatsEligibilityModule,
 *             _implementationsAddresses.playerHatsEligibilityModule,
 *             _implementationsAddresses.characterHatsEligibilityModule,
 *             _implementationsAddresses.hatsAdaptorImplementation,
 *             _implementationsAddresses.characterEligibilityAdaptorImplementation,
 *             _implementationsAddresses.classLevelAdaptorImplementation
 *         ) = abi.decode(
 *             encodedAdaptorsAndModuleAddresses, (address, address, address, address, address, address, address)
 *         );
 *     }
 * 
 *     function _initExternalAddresses(bytes calldata encodedExternalAddresses) internal {
 *         (
 *             _implementationsAddresses.erc6551Registry,
 *             _implementationsAddresses.hatsContract,
 *             _implementationsAddresses.hatsModuleFactory
 *         ) = abi.decode(encodedExternalAddresses, (address, address, address));
 *     }
 */
contract DeployImplementationAddressStorage is BaseDeployer {
    using stdJson for string;

    ImplementationAddresses public implementationAddresses;

    function loadBaseAddresses(string memory json, string memory targetEnv) internal {
        implementationAddresses.characterSheetsImplementation =
            json.readAddress(string(abi.encodePacked(".", targetEnv, ".CharacterSheetsImplementation")));
        implementationAddresses.itemsImplementation =
            json.readAddress(string(abi.encodePacked(".", targetEnv, ".ItemsImplementation")));
        implementationAddresses.itemsManagerImplementation =
            json.readAddress(string(abi.encodePacked(".", targetEnv, ".ItemsManagerImplementation")));
        implementationAddresses.classesImplementation =
            json.readAddress(string(abi.encodePacked(".", targetEnv, ".ClassesImplementation")));
        implementationAddresses.experienceImplementation =
            json.readAddress(string(abi.encodePacked(".", targetEnv, ".ExperienceImplementation")));
        implementationAddresses.erc6551Registry =
            json.readAddress(string(abi.encodePacked(".", targetEnv, ".Erc6551Registry")));
        implementationAddresses.erc6551AccountImplementation =
            json.readAddress(string(abi.encodePacked(".", targetEnv, ".Erc6551AccountImplementation")));
        implementationAddresses.characterEligibilityAdaptorImplementation =
            json.readAddress(string(abi.encodePacked(".", targetEnv, ".CharacterEligibilityAdaptorImplementation")));
        implementationAddresses.classLevelAdaptorImplementation =
            json.readAddress(string(abi.encodePacked(".", targetEnv, ".ClassLevelAdaptorImplementation")));
        implementationAddresses.hatsAdaptorImplementation =
            json.readAddress(string(abi.encodePacked(".", targetEnv, ".HatsAdaptorImplementation")));
        implementationAddresses.cloneAddressStorage =
            json.readAddress(string(abi.encodePacked(".", targetEnv, ".CloneAddressStorage")));

        implementationAddresses.hatsContract =
            json.readAddress(string(abi.encodePacked(".", targetEnv, ".HatsContract")));
        implementationAddresses.hatsModuleFactory =
            json.readAddress(string(abi.encodePacked(".", targetEnv, ".HatsModuleFactory")));

        implementationAddresses.adminHatsEligibilityModule =
            json.readAddress(string(abi.encodePacked(".", targetEnv, ".AdminHatsEligibilityModule")));
        implementationAddresses.dungeonMasterHatsEligibilityModule =
            json.readAddress(string(abi.encodePacked(".", targetEnv, ".DungeonMasterHatsEligibilityModule")));
        implementationAddresses.playerHatsEligibilityModule =
            json.readAddress(string(abi.encodePacked(".", targetEnv, ".PlayerHatsEligibilityModule")));
        implementationAddresses.characterHatsEligibilityModule =
            json.readAddress(string(abi.encodePacked(".", targetEnv, ".CharacterHatsEligibilityModule")));
    }

    function deploy() internal override returns (address) {
        bytes memory encodedImplementationAddresses = abi.encode(
            implementationAddresses.characterSheetsImplementation,
            implementationAddresses.itemsImplementation,
            implementationAddresses.classesImplementation,
            implementationAddresses.experienceImplementation,
            implementationAddresses.cloneAddressStorage,
            implementationAddresses.itemsManagerImplementation,
            implementationAddresses.erc6551AccountImplementation
        );

        bytes memory encodedAdaptorsAndModuleAddresses = abi.encode(
            implementationAddresses.adminHatsEligibilityModule,
            implementationAddresses.dungeonMasterHatsEligibilityModule,
            implementationAddresses.playerHatsEligibilityModule,
            implementationAddresses.characterHatsEligibilityModule,
            implementationAddresses.hatsAdaptorImplementation,
            implementationAddresses.characterEligibilityAdaptorImplementation,
            implementationAddresses.classLevelAdaptorImplementation
        );

        bytes memory encodedExternalAddresses = abi.encode(
            implementationAddresses.erc6551Registry,
            implementationAddresses.hatsContract,
            implementationAddresses.hatsModuleFactory
        );

        vm.startBroadcast(deployerPrivateKey);

        ImplementationAddressStorage newStorage = new ImplementationAddressStorage();
        newStorage.initialize(
            encodedImplementationAddresses, encodedAdaptorsAndModuleAddresses, encodedExternalAddresses
        );
        vm.stopBroadcast();

        return address(implementationAddressStorage);
    }
}
