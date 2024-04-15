// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
//solhint-disable

import "forge-std/Script.sol";
import "forge-std/StdJson.sol";
import "forge-std/console2.sol";

import {ForkManagement} from "./helpers/ForkManagement.sol";

abstract contract BaseDeployer is Script, ForkManagement {
    using stdJson for string;

    string public _version = "0.0.1";
    uint256 deployerPrivateKey;
    address deployer;

    bytes32 public SALT = bytes32(keccak256(abi.encode("CS")));
    address public CREATE2_DEPLOYER = address(0x4e59b44847b379578588920cA78FbF26c0B4956C);

    function loadBaseAddresses(string memory json, string memory targetEnv) internal virtual {
        // empty
    }

    function getDeploymentAddress(bytes memory creationCode, bytes memory params) internal view returns (address) {
        bytes32 newContract = keccak256(
            abi.encodePacked(bytes1(0xff), CREATE2_DEPLOYER, SALT, keccak256(abi.encodePacked(creationCode, params)))
        );
        return address(uint160(uint256(newContract)));
    }

    function getDeploymentAddress(bytes memory creationCode) internal view returns (address) {
      return getDeploymentAddress(creationCode, "");
    }

    function isContract(address a) public view returns (bool) {
        uint32 size;
        assembly {
            size := extcodesize(a)
        }
        return (size > 0);
    }

    function loadPrivateKeys() internal {
        string memory mnemonic = vm.envString("MNEMONIC");

        if (bytes(mnemonic).length > 0) {
            (deployer, deployerPrivateKey) = deriveRememberKey(mnemonic, 0);
        } else {
            deployerPrivateKey = vm.envUint("PRIVATE_KEY");
            deployer = vm.addr(deployerPrivateKey);
        }

        console2.log("\n");
        console2.log("Deployer address:", deployer);
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
