// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
//solhint-disable

import "forge-std/Script.sol";
import "forge-std/StdJson.sol";
import {ForkManagement} from "./helpers/ForkManagement.sol";
import "forge-std/console2.sol";

abstract contract BaseDeployer is Script, ForkManagement {
    using stdJson for string;

    uint256 deployerPrivateKey;
    address deployer;

    function loadBaseAddresses(string memory json, string memory targetEnv) internal virtual {
        // empty
    }

    function loadPrivateKeys() internal {
        string memory mnemonic = vm.envString("MNEMONIC");

        if (bytes(mnemonic).length > 0) {
            (deployer, deployerPrivateKey) = deriveRememberKey(mnemonic, 0);
        } else {
            deployerPrivateKey = vm.envUint("PRIVATE_KEY");
            deployer = vm.addr(deployerPrivateKey);
        }

        console2.log("\nDeployer address:", deployer);
        console2.log("Deployer balance:", deployer.balance);
    }

    function run(string calldata targetEnv) external {
        string memory json = loadJson();
        checkNetworkParams(json, targetEnv);
        loadBaseAddresses(json, targetEnv);
        loadPrivateKeys();

        address module = deploy();
        console.log("New Deployment Address:", address(module));
    }

    function deploy() internal virtual returns (address) {}
}