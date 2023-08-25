// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import {CharacterSheetsFactory} from "../src/CharacterSheetsFactory.sol";

import {BaseDeployer} from "./BaseDeployer.sol";
import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

contract DeployCharacterSheetsFactory is BaseDeployer {
  using stdJson for string;

  address public erc6551Registry;
  address public erc6551AccountImplementation;
  address public characterSheetsImplementation;
  address public experienceAndItemsImplementation;
  address public classesImplementation;

  CharacterSheetsFactory public characterSheetsFactory;

  function loadBaseAddresses(string memory json, string memory targetEnv) internal override {
    erc6551Registry = json.readAddress(string(abi.encodePacked(".", targetEnv, ".Erc6551Registry")));
    erc6551AccountImplementation = json.readAddress(string(abi.encodePacked(".", targetEnv, ".CharacterAccount")));
    characterSheetsImplementation = json.readAddress(string(abi.encodePacked(".", targetEnv, ".CharacterSheetsImplementation")));
    experienceAndItemsImplementation = json.readAddress(string(abi.encodePacked(".", targetEnv, ".ExperienceAndItemsImplementation")));
    classesImplementation = json.readAddress(string(abi.encodePacked(".", targetEnv, ".ClassesImplementation")));
  }

  function deploy() internal override returns (address) {
    require(erc6551AccountImplementation != address(0), "unknown erc6551AccountImplementation");
    require(erc6551Registry != address(0), "unknown erc6551Registry");
    require(characterSheetsImplementation != address(0), "unknown characterSheetsImplementation");
    require(experienceAndItemsImplementation != address(0), "unknown experienceAndItemsImplementation");
    require(classesImplementation != address(0), "unknown classesImplementation");

    vm.startBroadcast(deployerPrivateKey);

    characterSheetsFactory = new CharacterSheetsFactory();
    
    characterSheetsFactory.initialize();
    characterSheetsFactory.updateCharacterSheetsImplementation(characterSheetsImplementation);
    characterSheetsFactory.updateExperienceAndItemsImplementation(experienceAndItemsImplementation);
    characterSheetsFactory.updateERC6551Registry(erc6551Registry);
    characterSheetsFactory.updateERC6551AccountImplementation(erc6551AccountImplementation);
    characterSheetsFactory.updateClassesImplementation(classesImplementation);

    vm.stopBroadcast();

    return address(characterSheetsFactory);
  }
}