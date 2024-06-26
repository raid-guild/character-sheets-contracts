// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

import {CharacterSheetsFactory} from "../src/CharacterSheetsFactory.sol";

import {BaseDeployer} from "./BaseDeployer.sol";
import {BaseExecutor} from "./BaseExecutor.sol";

struct HatsStrings {
    string _baseImgUri;
    string topHatDescription;
    string adminUri;
    string adminDescription;
    string gameMasterUri;
    string gameMasterDescription;
    string playerUri;
    string playerDescription;
    string characterUri;
    string characterDescription;
}

struct SheetsStrings {
    address characterSheetsFactory;
    string characterSheetsMetadataUri;
    string characterSheetsBaseUri;
    string itemsBaseUri;
    string classesBaseUri;
    address characterSheetsAddress;
}

contract DeployCharacterSheetsFactory is BaseDeployer {
    using stdJson for string;

    address public implementationAddressStorage;

    CharacterSheetsFactory public characterSheetsFactory;

    function loadBaseAddresses(string memory json, string memory targetEnv) internal override {
        implementationAddressStorage =
            json.readAddress(string(abi.encodePacked(".", targetEnv, ".ImplementationAddressStorage")));
    }

    function deploy() internal override returns (address) {
        require(implementationAddressStorage != address(0), "impSto address(0)");

        vm.startBroadcast(deployerPrivateKey);

        address newContractAddress = getDeploymentAddress(type(CharacterSheetsFactory).creationCode);

        if (!isContract(newContractAddress)) {
            characterSheetsFactory = new CharacterSheetsFactory{salt: SALT}();

            characterSheetsFactory.initialize(implementationAddressStorage);
            assert(address(characterSheetsFactory) == newContractAddress);
        }

        vm.stopBroadcast();

        return newContractAddress;
    }
}

contract Create is BaseExecutor {
    using stdJson for string;

    address[] public gameMasters;
    address[] public admins;
    address public dao;

    address public clonesAddressStorage;
    address public implementationStorageAddress;

    SheetsStrings public sheetsStrings;
    HatsStrings public hatsStrings;

    bytes public encodedSheetsStrings;
    bytes public encodedHatsAddresses;
    bytes public encodedHatsStrings;

    CharacterSheetsFactory public factory;

    function loadBaseData(string memory json, string memory targetEnv) internal override {
        // addresses
        dao = json.readAddress(string(abi.encodePacked(".", targetEnv, ".Dao")));
        address characterSheetsFactory =
            json.readAddress(string(abi.encodePacked(".", targetEnv, ".CharacterSheetsFactory")));
        gameMasters = json.readAddressArray(string(abi.encodePacked(".", targetEnv, ".GameMasters")));
        implementationStorageAddress =
            json.readAddress(string(abi.encodePacked(".", targetEnv, ".ImplementationAddressStorage")));

        // sheets uri strings
        sheetsStrings.characterSheetsMetadataUri =
            json.readString(string(abi.encodePacked(".", targetEnv, ".CharacterSheetsMetadataUri")));
        sheetsStrings.characterSheetsBaseUri =
            json.readString(string(abi.encodePacked(".", targetEnv, ".CharacterSheetsBaseUri")));
        sheetsStrings.itemsBaseUri = json.readString(string(abi.encodePacked(".", targetEnv, ".ItemsBaseUri")));
        sheetsStrings.classesBaseUri = json.readString(string(abi.encodePacked(".", targetEnv, ".ClassesBaseUri")));

        // hats strings
        hatsStrings._baseImgUri = json.readString(string(abi.encodePacked(".", targetEnv, ".HatsBaseUri")));
        hatsStrings.topHatDescription = json.readString(string(abi.encodePacked(".", targetEnv, ".TopHatDescription")));
        hatsStrings.adminUri = json.readString(string(abi.encodePacked(".", targetEnv, ".AdminImgUri")));
        hatsStrings.adminDescription = json.readString(string(abi.encodePacked(".", targetEnv, ".AdminDescription")));
        hatsStrings.gameMasterUri = json.readString(string(abi.encodePacked(".", targetEnv, ".GameMasterImgUri")));
        hatsStrings.gameMasterDescription =
            json.readString(string(abi.encodePacked(".", targetEnv, ".GameMasterDescription")));
        hatsStrings.playerUri = json.readString(string(abi.encodePacked(".", targetEnv, ".PlayerUri")));
        hatsStrings.playerDescription = json.readString(string(abi.encodePacked(".", targetEnv, ".PlayerDescription")));
        hatsStrings.characterUri = json.readString(string(abi.encodePacked(".", targetEnv, ".CharacterUri")));
        hatsStrings.characterDescription =
            json.readString(string(abi.encodePacked(".", targetEnv, ".CharacterDescription")));

        // init and encode
        factory = CharacterSheetsFactory(characterSheetsFactory);
        encodedSheetsStrings = "";
        // abi.encode(characterSheetsMetadataUri, characterSheetsBaseUri, itemsBaseUri, classesBaseUri);
        encodedHatsAddresses = "";
        // abi.encode(arg);
    }

    function execute() internal override {
        vm.startBroadcast(deployerPrivateKey);
        clonesAddressStorage = factory.create(dao);
        vm.stopBroadcast();
    }
}
