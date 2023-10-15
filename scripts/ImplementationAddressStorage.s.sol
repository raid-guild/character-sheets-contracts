// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ImplementationAddressStorage} from "../src/ImplementationAddressStorage.sol";

import {BaseDeployer} from "./BaseDeployer.sol";
import {BaseFactoryExecutor} from "./BaseExecutor.sol";
import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

contract DeployImplementationAddressStorage is BaseDeployer {
    using stdJson for string;

    ImplementationAddressStorage public implementationAddressStorage;

    function deploy() internal override returns (address) {
        vm.startBroadcast(deployerPrivateKey);

        implementationAddressStorage = new ImplementationAddressStorage();

        vm.stopBroadcast();

        return address(implementationAddressStorage);
    }
}
