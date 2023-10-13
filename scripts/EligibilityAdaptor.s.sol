// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {CharacterEligibilityAdaptor} from "../src/adaptors/CharacterEligibilityAdaptor.sol";

import {BaseDeployer} from "./BaseDeployer.sol";
import {BaseFactoryExecutor} from "./BaseExecutor.sol";
import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

contract DeployCharacterEligibilityAdaptor is BaseDeployer {
    using stdJson for string;

    CharacterEligibilityAdaptor public CharacterEligibilityAdaptor;

    function deploy() internal override returns (address) {
        vm.startBroadcast(deployerPrivateKey);

        CharacterEligibilityAdaptor = new CharacterEligibilityAdaptor();

        vm.stopBroadcast();

        return address(CharacterEligibilityAdaptor);
    }
}
