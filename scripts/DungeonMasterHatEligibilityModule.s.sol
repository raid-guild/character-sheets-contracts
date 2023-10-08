// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {DungeonMasterHatEligibilityModule} from "../src/adaptors/hats-modules/DungeonMasterHatEligibilityModule.sol";

import {BaseDeployer} from "./BaseDeployer.sol";
import {BaseFactoryExecutor} from "./BaseExecutor.sol";
import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

contract DeployDungeonMasterHatEligibilityModule is BaseDeployer {
    using stdJson for string;

    DungeonMasterHatEligibilityModule public dungeonMasterHatEligibilityModule;

    function deploy() internal override returns (address) {
        vm.startBroadcast(deployerPrivateKey);

        dungeonMasterHatEligibilityModule = new DungeonMasterHatEligibilityModule(_version);

        vm.stopBroadcast();

        return address(dungeonMasterHatEligibilityModule);
    }
}
