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
    address molochV2EligibilityAdaptorImplementation;
    address molochV3EligibilityAdaptorImplementation;
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
            _encodeModuleAddresses(),
            _encodeAdaptorAddresses(),
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
        implementationAddresses.molochV2EligibilityAdaptorImplementation =
            json.readAddress(string(abi.encodePacked(".", targetEnv, ".MolochV2EligibilityAdaptor")));
        implementationAddresses.molochV3EligibilityAdaptorImplementation =
            json.readAddress(string(abi.encodePacked(".", targetEnv, ".MolochV3EligibilityAdaptor")));
        hatsAddresses.adminHatsEligibilityModule =
            json.readAddress(string(abi.encodePacked(".", targetEnv, ".AdminHatEligibilityModule")));
        hatsAddresses.gameMasterHatsEligibilityModule =
            json.readAddress(string(abi.encodePacked(".", targetEnv, ".GameMasterHatEligibilityModule")));
        hatsAddresses.playerHatsEligibilityModule =
            json.readAddress(string(abi.encodePacked(".", targetEnv, ".PlayerHatEligibilityModule")));
        hatsAddresses.characterHatsEligibilityModule =
            json.readAddress(string(abi.encodePacked(".", targetEnv, ".CharacterHatEligibilityModule")));
    }

    function _loadExternalAddresses(string memory json, string memory targetEnv) internal {
        implementationAddresses.classLevelAdaptorImplementation =
            json.readAddress(string(abi.encodePacked(".", targetEnv, ".ClassLevelAdaptor")));
        implementationAddresses.hatsAdaptorImplementation =
            json.readAddress(string(abi.encodePacked(".", targetEnv, ".HatsAdaptor")));
        implementationAddresses.cloneAddressStorage =
            json.readAddress(string(abi.encodePacked(".", targetEnv, ".ClonesAddressStorageImplementation")));
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
            implementationAddresses.molochV2EligibilityAdaptorImplementation,
            implementationAddresses.molochV3EligibilityAdaptorImplementation,
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
