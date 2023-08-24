// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import {CharacterSheetsFactory} from "../src/factories/CharacterSheetsFactory.sol";

import {BaseDeployer} from "./BaseDeployer.sol";
import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

contract DeployCharacterSheetsFactory is BaseDeployer {
  using stdJson for string;

  address public erc6551Registry;
  address public erc6551AccountImplementation;
  address public characterSheetsImplementation;
  address public experienceAndItemsImplementation;
  address public hatsAddress;

  CharacterSheetsFactory public characterSheetsFactory;

  function loadBaseAddresses(string memory json, string memory targetEnv) internal override {
    erc6551Registry = json.readAddress(string(abi.encodePacked(".", targetEnv, ".Erc6551Registry")));
    erc6551AccountImplementation = json.readAddress(string(abi.encodePacked(".", targetEnv, ".Erc6551AccountImplementation")));
    characterSheetsImplementation = json.readAddress(string(abi.encodePacked(".", targetEnv, ".CharacterSheetsImplementation")));
    experienceAndItemsImplementation = json.readAddress(string(abi.encodePacked(".", targetEnv, ".ExperienceAndItemsImplementation")));
  }

  function deploy() internal override returns (address) {
    vm.startBroadcast(deployerPrivateKey);

    characterSheetsFactory = new CharacterSheetsFactory();
    
    characterSheetsFactory.initialize();
    characterSheetsFactory.updateCharacterSheetsImplementation(characterSheetsImplementation);
    characterSheetsFactory.updateExperienceAndItemsImplementation(experienceAndItemsImplementation);
    characterSheetsFactory.updateERC6551Registry(erc6551Registry);
    characterSheetsFactory.updateERC6551AccountImplementation(erc6551AccountImplementation);

    vm.stopBroadcast();

    return address(characterSheetsFactory);
  }
}