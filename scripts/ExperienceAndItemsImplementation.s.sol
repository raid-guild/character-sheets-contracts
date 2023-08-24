// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import {ExperienceAndItemsImplementation} from "../src/implementations/ExperienceAndItemsImplementation.sol";

import {BaseDeployer} from "./BaseDeployer.sol";
import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

contract DeployExperienceAndItemsImplementation is BaseDeployer {
  using stdJson for string;

  ExperienceAndItemsImplementation public experienceAndItemsImplementation;

  function deploy() internal override returns (address) {
    vm.startBroadcast(deployerPrivateKey);

    experienceAndItemsImplementation = new ExperienceAndItemsImplementation();
    
    vm.stopBroadcast();

    return address(experienceAndItemsImplementation);
  }
}