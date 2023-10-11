// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {CharacterHatEligibilityModule} from "../src/adaptors/hats-modules/CharacterHatEligibilityModule.sol";

import {BaseDeployer} from "./BaseDeployer.sol";
import {BaseFactoryExecutor} from "./BaseExecutor.sol";
import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

contract DeployCharacterHatEligibilityModule is BaseDeployer {
    using stdJson for string;

    CharacterHatEligibilityModule public characterHatEligibilityModule;

    function deploy() internal override returns (address) {
        vm.startBroadcast(deployerPrivateKey);

        characterHatEligibilityModule = new CharacterHatEligibilityModule(_version);

        vm.stopBroadcast();

        return address(characterHatEligibilityModule);
    }
}
