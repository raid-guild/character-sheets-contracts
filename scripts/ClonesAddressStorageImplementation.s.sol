// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ClonesAddressStorageImplementation} from "../src/implementations/ClonesAddressStorageImplementation.sol";

import {BaseDeployer} from "./BaseDeployer.sol";
import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

contract DeployClonesAddressStorageImplementation is BaseDeployer {
    using stdJson for string;

    ClonesAddressStorageImplementation public clonesAddressStorage;

    function deploy() internal override returns (address) {
        vm.startBroadcast(deployerPrivateKey);

        clonesAddressStorage = new ClonesAddressStorageImplementation();

        vm.stopBroadcast();

        return address(clonesAddressStorage);
    }
}
