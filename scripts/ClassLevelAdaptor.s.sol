// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ClassLevelAdaptor} from "../src/adaptors/ClassLevelAdaptor.sol";

import {BaseDeployer} from "./BaseDeployer.sol";
import {BaseFactoryExecutor} from "./BaseExecutor.sol";
import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

contract DeployClassLevelAdaptor is BaseDeployer {
    using stdJson for string;

    ClassLevelAdaptor public classLevelAdaptor;

    function deploy() internal override returns (address) {
        vm.startBroadcast(deployerPrivateKey);

        classLevelAdaptor = new ClassLevelAdaptor();

        vm.stopBroadcast();

        return address(classLevelAdaptor);
    }
}
