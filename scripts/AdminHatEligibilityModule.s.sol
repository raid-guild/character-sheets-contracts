// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {AdminHatEligibilityModule} from "../src/adaptors/hats-modules/AdminHatEligibilityModule.sol";

import {BaseDeployer} from "./BaseDeployer.sol";
import {BaseFactoryExecutor} from "./BaseExecutor.sol";
import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

contract DeployAdminHatEligibilityModule is BaseDeployer {
    using stdJson for string;

    AdminHatEligibilityModule public adminHatEligibilityModule;

    function deploy() internal override returns (address) {
        vm.startBroadcast(deployerPrivateKey);

        adminHatEligibilityModule = new AdminHatEligibilityModule(_version);

        vm.stopBroadcast();

        return address(adminHatEligibilityModule);
    }
}
