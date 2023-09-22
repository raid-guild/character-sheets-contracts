// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {EligibilityAdaptor} from "../src/EligibilityAdaptor.sol";

import {BaseDeployer} from "./BaseDeployer.sol";
import {BaseFactoryExecutor} from "./BaseExecutor.sol";
import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

contract DeployEligibilityAdaptor is BaseDeployer {
    using stdJson for string;

    address public dao;

    EligibilityAdaptor public eligibilityAdaptor;

    function loadBaseAddresses(string memory json, string memory targetEnv) internal override {
        dao = json.readAddress(string(abi.encodePacked(".", targetEnv, ".Dao")));
    }

    function deploy() internal override returns (address) {
        require(dao != address(0), "unknown erc6551AccountImplementation");

        vm.startBroadcast(deployerPrivateKey);

        eligibilityAdaptor = new EligibilityAdaptor();

        eligibilityAdaptor.updateDaoAddress(dao);

        vm.stopBroadcast();

        return address(eligibilityAdaptor);
    }
}
