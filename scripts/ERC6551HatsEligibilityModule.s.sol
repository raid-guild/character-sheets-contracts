// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ERC6551HatsEligibilityModule} from "../src/adaptors/hats-modules/ERC6551HatsEligibilityModule.sol";

import {BaseDeployer} from "./BaseDeployer.sol";
import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

contract DeployERC6551HatsEligibilityModule is BaseDeployer {
    using stdJson for string;

    ERC6551HatsEligibilityModule public erc6551HatsEligibilityModule;

    function deploy() internal override returns (address) {
        vm.startBroadcast(deployerPrivateKey);

        address newContractAddress = getDeploymentAddress(type(ERC6551HatsEligibilityModule).creationCode, abi.encode(_version));

        if (!isContract(newContractAddress)) {
            erc6551HatsEligibilityModule = new ERC6551HatsEligibilityModule{salt: SALT}(_version);
            assert(address(erc6551HatsEligibilityModule) == newContractAddress);
        }

        vm.stopBroadcast();

        return newContractAddress;
    }
}
