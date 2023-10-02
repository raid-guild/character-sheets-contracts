// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {EligibilityAdaptor} from "../src/adaptors/EligibilityAdaptor.sol";

import {BaseDeployer} from "./BaseDeployer.sol";
import {BaseFactoryExecutor} from "./BaseExecutor.sol";
import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

contract DeployEligibilityAdaptor is BaseDeployer {
    using stdJson for string;

    EligibilityAdaptor public eligibilityAdaptor;

    function deploy() internal override returns (address) {
        vm.startBroadcast(deployerPrivateKey);

        eligibilityAdaptor = new EligibilityAdaptor();

        vm.stopBroadcast();

        return address(eligibilityAdaptor);
    }
}
