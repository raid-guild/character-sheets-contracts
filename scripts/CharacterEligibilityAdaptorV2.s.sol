// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {CharacterEligibilityAdaptorV2} from "../src/adaptors/CharacterEligibilityAdaptorV2.sol";

import {BaseDeployer} from "./BaseDeployer.sol";
import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

contract DeployCharacterEligibilityAdaptorV2 is BaseDeployer {
    using stdJson for string;

    CharacterEligibilityAdaptorV2 public characterEligibilityAdaptorV2;

    function deploy() internal override returns (address) {
        vm.startBroadcast(deployerPrivateKey);

        characterEligibilityAdaptorV2 = new CharacterEligibilityAdaptorV2();

        vm.stopBroadcast();

        return address(characterEligibilityAdaptorV2);
    }
}
