// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {CharacterSheetsLevelEligibilityModule} from
    "../src/adaptors/hats-modules/CharacterSheetsLevelEligibilityModule.sol";

import {BaseDeployer} from "./BaseDeployer.sol";
import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

contract DeployCharacterSheetsLevelEligibilityModule is BaseDeployer {
    using stdJson for string;

    CharacterSheetsLevelEligibilityModule public characterSheetsLevelEligibilityModule;

    function deploy() internal override returns (address) {
        vm.startBroadcast(deployerPrivateKey);

        characterSheetsLevelEligibilityModule = new CharacterSheetsLevelEligibilityModule(_version);

        vm.stopBroadcast();

        return address(characterSheetsLevelEligibilityModule);
    }
}
