// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ClassesImplementation} from "../src/implementations/ClassesImplementation.sol";

import {BaseDeployer} from "./BaseDeployer.sol";
//solhint-disable
import "../lib/forge-std/src/Script.sol";
import "../lib/forge-std/src/StdJson.sol";

contract DeployClassesImplementation is BaseDeployer {
  using stdJson for string;

  ClassesImplementation public classesImplementation;

  function deploy() internal override returns (address) {
    vm.startBroadcast(deployerPrivateKey);

    classesImplementation = new ClassesImplementation();
    
    
    vm.stopBroadcast();

    return address(classesImplementation);
  }
}