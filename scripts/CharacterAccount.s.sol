// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {CharacterAccount} from "../src/CharacterAccount.sol";

import {BaseDeployer} from "./BaseDeployer.sol";
//solhint-disable
import "../lib/forge-std/src/Script.sol";
import "../lib/forge-std/src/StdJson.sol";

contract DeployCharacterAccount is BaseDeployer {
    using stdJson for string;

    CharacterAccount public characterAccount;

    function deploy() internal override returns (address) {
        vm.startBroadcast(deployerPrivateKey);

        characterAccount = new CharacterAccount();

        vm.stopBroadcast();

        return address(characterAccount);
    }
}
