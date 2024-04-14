// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

import {ItemsImplementation} from "../src/implementations/ItemsImplementation.sol";
import {BaseExecutor} from "./BaseExecutor.sol";
import {BaseDeployer} from "./BaseDeployer.sol";
import "../src/lib/Structs.sol";

contract DeployItemsImplementation is BaseDeployer {
    using stdJson for string;

    ItemsImplementation public itemsImplementation;

    function deploy() internal override returns (address) {
        vm.startBroadcast(deployerPrivateKey);

        address newContractAddress = getDeploymentAddress(type(ItemsImplementation).creationCode);

        if (!isContract(newContractAddress)) {
            itemsImplementation = new ItemsImplementation{salt: SALT}();
            assert(address(itemsImplementation) == newContractAddress);
        }

        vm.stopBroadcast();

        return newContractAddress;
    }
}

contract ExecuteItemsImplementation is BaseExecutor {
    using stdJson for string;

    ItemsImplementation public experience;
    address public experienceAddress;
    string public itemName;
    uint256 public supply;
    string public uri;
    bool public soulbound;
    uint256[][] public itemRequirements;
    uint256[] public classRequirements;
    uint256[][] public merkle;

    function loadBaseData(string memory json, string memory targetEnv) internal override {
        experienceAddress = json.readAddress(string(abi.encodePacked(".", targetEnv, ".CreatedExperienceAndItems")));
        experience = ItemsImplementation(experienceAddress);
        uri = json.readString(string(abi.encodePacked(".", targetEnv, ".Items[", arrIndex, "].cid")));
        soulbound = json.readBool(string(abi.encodePacked(".", targetEnv, ".Items[", arrIndex, "].soulbound")));
        supply = json.readUint(string(abi.encodePacked(".", targetEnv, ".Items[", arrIndex, "].supply")));
        itemName = json.readString(string(abi.encodePacked(".", targetEnv, ".Items[", arrIndex, "].name")));
        classRequirements = json.readUintArray(
            string(abi.encodePacked(".", targetEnv, ".Items[", arrIndex, "].requirements.classRequirements"))
        );

        bytes memory intermediaryBytesItem = json.parseRaw(
            string(abi.encodePacked(".", targetEnv, ".Items[", arrIndex, "].requirements.itemRequirements"))
        );
        (itemRequirements) = abi.decode(intermediaryBytesItem, (uint256[][]));
        bytes memory merkleData =
            json.parseRaw(string(abi.encodePacked(".", targetEnv, ".Items[", arrIndex, "].requirements.claimable")));
        (merkle) = abi.decode(merkleData, (uint256[][]));
    }

    function execute() internal override {
        bytes32 merkleRoot = _createMerkleRoot();
        bytes memory encodedData =
            abi.encode(itemName, supply, itemRequirements, classRequirements, soulbound, merkleRoot, uri);

        vm.broadcast(deployerPrivateKey);
        uint256 newItemId = experience.createItemType(encodedData);
        console.log("New Item Id: ", newItemId);
    }

    function _createMerkleRoot() internal pure returns (bytes32) {
        return bytes32(0);
    }
}
