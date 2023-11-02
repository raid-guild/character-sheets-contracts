// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {GameMasterHatEligibilityModule} from "../src/adaptors/hats-modules/GameMasterHatEligibilityModule.sol";

import {BaseDeployer} from "./BaseDeployer.sol";
import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

contract DeployGameMasterHatEligibilityModule is BaseDeployer {
    using stdJson for string;

    GameMasterHatEligibilityModule public gameMasterHatEligibilityModule;

    function deploy() internal override returns (address) {
        vm.startBroadcast(deployerPrivateKey);

        gameMasterHatEligibilityModule = new GameMasterHatEligibilityModule(_version);

        vm.stopBroadcast();

        return address(gameMasterHatEligibilityModule);
    }
}
