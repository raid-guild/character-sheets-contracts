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

        address newContractAddress = getDeploymentAddress(type(ClonesAddressStorageImplementation).creationCode);

        if (!isContract(newContractAddress)) {
            clonesAddressStorage = new ClonesAddressStorageImplementation{salt: SALT}();
            assert(address(clonesAddressStorage) == newContractAddress);
        }

        vm.stopBroadcast();

        return newContractAddress;
    }
}
