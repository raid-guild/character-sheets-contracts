// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {CharacterEligibilityAdaptorV3} from "../src/adaptors/CharacterEligibilityAdaptorV3.sol";

import {BaseDeployer} from "./BaseDeployer.sol";
import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

contract DeployCharacterEligibilityAdaptorV3 is BaseDeployer {
    using stdJson for string;

    CharacterEligibilityAdaptorV3 public characterEligibilityAdaptorV3;

    function deploy() internal override returns (address) {
        vm.startBroadcast(deployerPrivateKey);

        characterEligibilityAdaptorV3 = new CharacterEligibilityAdaptorV3();

        vm.stopBroadcast();

        return address(characterEligibilityAdaptorV3);
    }
}
