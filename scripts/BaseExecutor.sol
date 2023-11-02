// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;
//solhint-disable

import "forge-std/Script.sol";
import "forge-std/StdJson.sol";
import "forge-std/console2.sol";

import {ForkManagement} from "./helpers/ForkManagement.sol";

contract BaseExecutor is Script, ForkManagement {
    using stdJson for string;

    uint256 deployerPrivateKey;
    address public deployer;
    string public arrIndex;

    function loadBaseData(string memory json, string memory targetEnv) internal virtual {
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

    function run(string calldata targetEnv, string calldata _index) external {
        string memory json = loadJson();
        checkNetworkParams(json, targetEnv);
        loadPrivateKeys();
        arrIndex = _index;

        loadBaseData(json, targetEnv);
        console2.log("INDEX SET: ", _index, arrIndex);

        execute();
    }

    function execute() internal virtual {}
}

/*
abstract contract BaseFactoryExecutor is Script, ForkManagement {
    using stdJson for string;

    uint256 deployerPrivateKey;
    address deployer;

    function loadBaseData(string memory json, string memory targetEnv) internal virtual {
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
        loadBaseData(json, targetEnv);
        loadPrivateKeys();

        (address characterSheetsAddresss, address classesAddress, address itemsAddress, address experienceAddress) =
            create();
        console.log("New Character Sheets Address:", characterSheetsAddresss);
        console.log("New Classes Address:", classesAddress);
        console.log("New Items Address:", itemsAddress);
        console.log("New Experience Address:", experienceAddress);
    }

    function create() internal virtual returns (address, address, address, address) {}

    function initializeContracts() internal virtual {}
}
*/
