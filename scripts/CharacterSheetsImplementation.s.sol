// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import {CharacterSheetsImplementation} from "../src/implementations/CharacterSheetsImplementation.sol";

import {BaseDeployer} from "./BaseDeployer.sol";
import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

contract DeployCharacterSheetsImplementation is BaseDeployer {
  using stdJson for string;

  CharacterSheetsImplementation public characterSheetsImplementation;

  function deploy() internal override returns (address) {
    vm.startBroadcast(deployerPrivateKey);

    characterSheetsImplementation = new CharacterSheetsImplementation();
    
    vm.stopBroadcast();

    return address(characterSheetsImplementation);
  }
}