// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {MolochV3EligibilityAdaptor} from "../src/adaptors/MolochV3EligibilityAdaptor.sol";

import {BaseDeployer} from "./BaseDeployer.sol";
import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

contract DeployMolochV3EligibilityAdaptor is BaseDeployer {
    using stdJson for string;

    MolochV3EligibilityAdaptor public molochV3EligibilityAdaptor;

    function deploy() internal override returns (address) {
        vm.startBroadcast(deployerPrivateKey);

        address newContractAddress = getDeploymentAddress(type(MolochV3EligibilityAdaptor).creationCode);

        if (!isContract(newContractAddress)) {
            molochV3EligibilityAdaptor = new MolochV3EligibilityAdaptor{salt: SALT}();
            assert(address(molochV3EligibilityAdaptor) == newContractAddress);
        }

        vm.stopBroadcast();

        return newContractAddress;
    }
}
