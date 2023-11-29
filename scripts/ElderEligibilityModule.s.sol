// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ElderEligibilityModule} from "../src/adaptors/hats-modules/ElderEligibilityModule.sol";

import {BaseDeployer} from "./BaseDeployer.sol";
import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

contract DeployElderEligibilityModule is BaseDeployer {
    using stdJson for string;

    ElderEligibilityModule public elderEligibilityModule;

    function deploy() internal override returns (address) {
        vm.startBroadcast(deployerPrivateKey);

        elderEligibilityModule = new ElderEligibilityModule(_version);

        vm.stopBroadcast();

        return address(elderEligibilityModule);
    }
}
