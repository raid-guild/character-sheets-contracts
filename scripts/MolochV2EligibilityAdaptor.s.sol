// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {MolochV2EligibilityAdaptor} from "../src/adaptors/MolochV2EligibilityAdaptor.sol";

import {BaseDeployer} from "./BaseDeployer.sol";
import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

contract DeployMolochV2EligibilityAdaptor is BaseDeployer {
    using stdJson for string;

    MolochV2EligibilityAdaptor public molochV2EligibilityAdaptor;

    function deploy() internal override returns (address) {
        vm.startBroadcast(deployerPrivateKey);

        address newContractAddress = getDeploymentAddress(type(MolochV2EligibilityAdaptor).creationCode);

        if (!isContract(newContractAddress)) {
            molochV2EligibilityAdaptor = new MolochV2EligibilityAdaptor{salt: SALT}();
            assert(address(molochV2EligibilityAdaptor) == newContractAddress);
        }

        vm.stopBroadcast();

        return newContractAddress;
    }
}
