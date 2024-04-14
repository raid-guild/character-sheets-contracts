// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {MultiERC6551HatsEligibilityModule} from "../src/adaptors/hats-modules/MultiERC6551HatsEligibilityModule.sol";

import {BaseDeployer} from "./BaseDeployer.sol";
import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

contract DeployMultiERC6551HatsEligibilityModule is BaseDeployer {
    using stdJson for string;

    MultiERC6551HatsEligibilityModule public multiERC6551HatsEligibilityModule;

    function deploy() internal override returns (address) {
        vm.startBroadcast(deployerPrivateKey);

        address newContractAddress = getDeploymentAddress(type(MultiERC6551HatsEligibilityModule).creationCode, abi.encode(_version));

        bytes memory params = abi.encode(_version);
        console2.logBytes32(bytes32(params));

        if (!isContract(newContractAddress)) {
            multiERC6551HatsEligibilityModule = new MultiERC6551HatsEligibilityModule{salt: SALT}(_version);
            assert(address(multiERC6551HatsEligibilityModule) == newContractAddress);
        }

        vm.stopBroadcast();

        return newContractAddress;
    }
}
