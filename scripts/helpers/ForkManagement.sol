// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

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
        view
        returns (string memory network, uint256 chainId)
    {
        network = json.readString(string(abi.encodePacked(".", targetEnv, ".network")));
        chainId = json.readUint(string(abi.encodePacked(".", targetEnv, ".chainId")));
        console2.log("Target environment:", targetEnv);
        console2.log("Network:", network);
        console2.log("ChainId:", chainId);
        if (block.chainid != chainId) revert("Wrong chainId");
    }

    function getNetwork(string memory json, string memory targetEnv) internal pure returns (string memory) {
        return json.readString(string(abi.encodePacked(".", targetEnv, ".network")));
    }
}
