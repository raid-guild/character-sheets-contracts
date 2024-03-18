// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {MultiERC6551HatsEligibilityModule} from "../src/adaptors/hats-modules/MultiERC6551HatsEligibilityModule.sol";

import {BaseDeployer} from "./BaseDeployer.sol";
import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

contract DeployMultiERC6551HatsEligibilityModule is BaseDeployer {
    using stdJson for string;

    MultiERC6551HatsEligibilityModule public erc6551HatsEligibilityModule;

    function deploy() internal override returns (address) {
        vm.startBroadcast(deployerPrivateKey);

        erc6551HatsEligibilityModule = new MultiERC6551HatsEligibilityModule(_version);

        vm.stopBroadcast();

        return address(erc6551HatsEligibilityModule);
    }
}
