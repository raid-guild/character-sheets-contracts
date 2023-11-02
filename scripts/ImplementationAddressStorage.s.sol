// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ImplementationAddressStorage} from "../src/ImplementationAddressStorage.sol";

import {BaseDeployer} from "./BaseDeployer.sol";
import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

struct ImplementationAddresses {
    // implementation addresses
    address characterSheetsImplementation;
    address itemsImplementation;
    address itemsManagerImplementation;
    address classesImplementation;
    address erc6551AccountImplementation;
    address experienceImplementation;
    address characterEligibilityAdaptorV2Implementation;
    address characterEligibilityAdaptorV3Implementation;
    address classLevelAdaptorImplementation;
    address hatsAdaptorImplementation;
    address cloneAddressStorage;
}

struct HatsAddresses {
    //hats addresses
    address hatsContract;
    address hatsModuleFactory;
    //eligibility modules
    address adminHatsEligibilityModule;
    address gameMasterHatsEligibilityModule;
    address playerHatsEligibilityModule;
    address characterHatsEligibilityModule;
    address erc6551Registry;
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
 *             _implementationsAddresses.gameMasterHatsEligibilityModule,
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

    ImplementationAddressStorage public implementationAddressStorage;

    HatsAddresses public hatsAddresses;

    function loadBaseAddresses(string memory json, string memory targetEnv) internal override {
        _loadImplementationaddresses(json, targetEnv);
        _loadAdaptorsAndModuleAddresses(json, targetEnv);
        _loadExternalAddresses(json, targetEnv);
    }

    function deploy() internal override returns (address) {
        vm.startBroadcast(deployerPrivateKey);

        implementationAddressStorage = new ImplementationAddressStorage();
        implementationAddressStorage.initialize(
            _encodeImplementationAddresses(),
            _encodeAdaptorAddresses(),
            _encodeModuleAddresses(),
            _encodeExternalAddresses()
        );
        vm.stopBroadcast();

        return address(implementationAddressStorage);
    }

    function _loadImplementationaddresses(string memory json, string memory targetEnv) internal {
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
    }

    function _loadAdaptorsAndModuleAddresses(string memory json, string memory targetEnv) internal {
        implementationAddresses.erc6551AccountImplementation =
            json.readAddress(string(abi.encodePacked(".", targetEnv, ".CharacterAccount")));
        implementationAddresses.characterEligibilityAdaptorV2Implementation =
            json.readAddress(string(abi.encodePacked(".", targetEnv, ".CharacterEligibilityAdaptorV2")));
        implementationAddresses.characterEligibilityAdaptorV3Implementation =
            json.readAddress(string(abi.encodePacked(".", targetEnv, ".CharacterEligibilityAdaptorV3")));
        hatsAddresses.adminHatsEligibilityModule =
            json.readAddress(string(abi.encodePacked(".", targetEnv, ".AdminHatsEligibilityModule")));
        hatsAddresses.gameMasterHatsEligibilityModule =
            json.readAddress(string(abi.encodePacked(".", targetEnv, ".GameMasterHatsEligibilityModule")));
        hatsAddresses.playerHatsEligibilityModule =
            json.readAddress(string(abi.encodePacked(".", targetEnv, ".PlayerHatsEligibilityModule")));
        hatsAddresses.characterHatsEligibilityModule =
            json.readAddress(string(abi.encodePacked(".", targetEnv, ".CharacterHatsEligibilityModule")));
    }

    function _loadExternalAddresses(string memory json, string memory targetEnv) internal {
        implementationAddresses.classLevelAdaptorImplementation =
            json.readAddress(string(abi.encodePacked(".", targetEnv, ".ClassLevelAdaptor")));
        implementationAddresses.hatsAdaptorImplementation =
            json.readAddress(string(abi.encodePacked(".", targetEnv, ".HatsAdaptor")));
        implementationAddresses.cloneAddressStorage =
            json.readAddress(string(abi.encodePacked(".", targetEnv, ".CloneAddressStorage")));
        hatsAddresses.hatsContract = json.readAddress(string(abi.encodePacked(".", targetEnv, ".HatsContract")));
        hatsAddresses.hatsModuleFactory =
            json.readAddress(string(abi.encodePacked(".", targetEnv, ".HatsModuleFactory")));
        hatsAddresses.erc6551Registry = json.readAddress(string(abi.encodePacked(".", targetEnv, ".Erc6551Registry")));
    }

    function _encodeImplementationAddresses() internal view returns (bytes memory) {
        bytes memory encodedImplementationAddresses = abi.encode(
            implementationAddresses.characterSheetsImplementation,
            implementationAddresses.itemsImplementation,
            implementationAddresses.classesImplementation,
            implementationAddresses.experienceImplementation,
            implementationAddresses.cloneAddressStorage,
            implementationAddresses.itemsManagerImplementation,
            implementationAddresses.erc6551AccountImplementation
        );
        return encodedImplementationAddresses;
    }

    function _encodeAdaptorAddresses() internal view returns (bytes memory) {
        bytes memory encodedAdaptorsAddresses = abi.encode(
            implementationAddresses.hatsAdaptorImplementation,
            implementationAddresses.characterEligibilityAdaptorV2Implementation,
            implementationAddresses.characterEligibilityAdaptorV3Implementation,
            implementationAddresses.classLevelAdaptorImplementation
        );

        return encodedAdaptorsAddresses;
    }

    function _encodeModuleAddresses() internal view returns (bytes memory) {
        bytes memory encodedModuleAddresses = abi.encode(
            hatsAddresses.adminHatsEligibilityModule,
            hatsAddresses.gameMasterHatsEligibilityModule,
            hatsAddresses.playerHatsEligibilityModule,
            hatsAddresses.characterHatsEligibilityModule
        );

        return encodedModuleAddresses;
    }

    function _encodeExternalAddresses() internal view returns (bytes memory) {
        bytes memory encodedExternalAddresses =
            abi.encode(hatsAddresses.erc6551Registry, hatsAddresses.hatsContract, hatsAddresses.hatsModuleFactory);

        return encodedExternalAddresses;
    }
}
