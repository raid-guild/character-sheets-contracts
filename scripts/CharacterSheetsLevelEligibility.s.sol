// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {CharacterSheetsLevelEligibility} from
    "../src/adaptors/hats-modules/CharacterSheetsLevelEligibility.sol";

import {BaseDeployer} from "./BaseDeployer.sol";
import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

contract DeployCharacterSheetsLevelEligibility is BaseDeployer {
    using stdJson for string;

    CharacterSheetsLevelEligibility public characterSheetsLevelEligibility;

    function deploy() internal override returns (address) {
        vm.startBroadcast(deployerPrivateKey);

        characterSheetsLevelEligibility = new CharacterSheetsLevelEligibility(_version);

        vm.stopBroadcast();

        return address(characterSheetsLevelEligibility);
    }
}
