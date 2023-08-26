// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

//solhint-disable

import "forge-std/Script.sol";
import "forge-std/console2.sol";

contract ForkManagement is Script {
    using stdJson for string;

    function loadJson() internal view returns (string memory) {
        string memory root = vm.projectRoot();
        string memory path = string(abi.encodePacked(root, "/addresses.json"));
        string memory json = vm.readFile(path);
        return json;
    }

    function checkNetworkParams(string memory json, string memory targetEnv)
        internal
        returns (string memory network, uint256 chainId)
    {
        console2.log(targetEnv);
        network = json.readString(string(abi.encodePacked(".", targetEnv, ".network")));
        chainId = json.readUint(string(abi.encodePacked(".", targetEnv, ".chainId")));
        console2.log("ChainId: ", chainId, block.chainid);
        console2.log("\nTarget environment:", targetEnv);
        console2.log("Network:", network);
        // if (block.chainid != chainId) revert("Wrong chainId");
        console2.log("ChainId:", chainId);
    }

    function getNetwork(string memory json, string memory targetEnv) internal returns (string memory) {
        return json.readString(string(abi.encodePacked(".", targetEnv, ".network")));
    }
}
