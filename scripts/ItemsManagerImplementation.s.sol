// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

import {ItemsManagerImplementation} from "../src/implementations/ItemsManagerImplementation.sol";
import {BaseExecutor} from "./BaseExecutor.sol";
import {BaseDeployer} from "./BaseDeployer.sol";
import "../src/lib/Structs.sol";

contract DeployItemsManagerImplementation is BaseDeployer {
    using stdJson for string;

    ItemsManagerImplementation public itemsManagerImplementation;

    function deploy() internal override returns (address) {
        vm.startBroadcast(deployerPrivateKey);

        address newContractAddress = getDeploymentAddress(type(ItemsManagerImplementation).creationCode);

        if (!isContract(newContractAddress)) {
            itemsManagerImplementation = new ItemsManagerImplementation{salt: SALT}();
            assert(address(itemsManagerImplementation) == newContractAddress);
        }

        vm.stopBroadcast();

        return newContractAddress;
    }
}
