// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ClonesAddressStorage} from "../src/implementations/ClonesAddressStorage.sol";

import {BaseDeployer} from "./BaseDeployer.sol";
import {BaseFactoryExecutor} from "./BaseExecutor.sol";
import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

contract DeployClonesAddressStorage is BaseDeployer {
    using stdJson for string;

    ClonesAddressStorage public clonesAddressStorage;

    function deploy() internal override returns (address) {
        vm.startBroadcast(deployerPrivateKey);

        clonesAddressStorage = new ClonesAddressStorage();

        vm.stopBroadcast();

        return address(clonesAddressStorage);
    }
}
