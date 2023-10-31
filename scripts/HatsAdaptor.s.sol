// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {HatsAdaptor} from "../src/adaptors/HatsAdaptor.sol";

import {BaseDeployer} from "./BaseDeployer.sol";
import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

contract DeployHatsAdaptor is BaseDeployer {
    using stdJson for string;

    HatsAdaptor public hatsAdaptor;

    function deploy() internal override returns (address) {
        vm.startBroadcast(deployerPrivateKey);

        hatsAdaptor = new HatsAdaptor();

        vm.stopBroadcast();

        return address(hatsAdaptor);
    }
}
