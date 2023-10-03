// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
//solhint-disable

import "forge-std/Script.sol";
import "forge-std/StdJson.sol";
import "forge-std/console2.sol";

import {CharacterAccount} from "../src/CharacterAccount.sol";
import {BaseDeployer} from "./BaseDeployer.sol";

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
