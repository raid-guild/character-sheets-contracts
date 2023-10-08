// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {PlayerHatEligibilityModule} from "../src/adaptors/hats-modules/PlayerHatEligibilityModule.sol";

import {BaseDeployer} from "./BaseDeployer.sol";
import {BaseFactoryExecutor} from "./BaseExecutor.sol";
import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

contract DeployPlayerHatEligibilityModule is BaseDeployer {
    using stdJson for string;

    PlayerHatEligibilityModule public playerHatEligibilityModule;

    function deploy() internal override returns (address) {
        vm.startBroadcast(deployerPrivateKey);

        playerHatEligibilityModule = new PlayerHatEligibilityModule(_version);

        vm.stopBroadcast();

        return address(playerHatEligibilityModule);
    }
}
