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

        address newContractAddress = getDeploymentAddress(type(HatsAdaptor).creationCode);

        if (!isContract(newContractAddress)) {
            hatsAdaptor = new HatsAdaptor{salt: SALT}();
            assert(address(hatsAdaptor) == newContractAddress);
        }

        vm.stopBroadcast();

        return newContractAddress;
    }
}
