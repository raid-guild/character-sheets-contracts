// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ClassesImplementation} from "../src/implementations/ClassesImplementation.sol";

import {BaseDeployer} from "./BaseDeployer.sol";
import {BaseExecutor} from "./BaseExecutor.sol";

//solhint-disable
import "../lib/forge-std/src/Script.sol";
import "../lib/forge-std/src/StdJson.sol";

contract DeployClassesImplementation is BaseDeployer {
    using stdJson for string;

    ClassesImplementation public classesImplementation;

    function deploy() internal override returns (address) {
        vm.startBroadcast(deployerPrivateKey);

        classesImplementation = new ClassesImplementation();

        vm.stopBroadcast();

        return address(classesImplementation);
    }
}

contract ExecuteClassesImplementation is BaseExecutor {
    event NewCharacter(uint256 tokenId, address tba);

    using stdJson for string;

    ClassesImplementation public classesImplementation;
    string public className;
    string public classUri;
    address characterAddress;
    bool claimable;

    function loadBaseData(string memory json, string memory targetEnv) internal override {
        address classes = json.readAddress(string(abi.encodePacked(".", targetEnv, ".CreatedClasses")));
        claimabl = json.readBool(string(abi.encodePacked(".", targetEnv, ".Classes[", arrIndex, "].Claimable")));
        classesImplementation = ClassesImplementation(classes);
        console2.log("ARR INDEX: ", arrIndex);
        className = json.readString(string(abi.encodePacked(".", targetEnv, ".Classes[", arrIndex, "].ClassName")));
        classUri = json.readString(string(abi.encodePacked(".", targetEnv, ".Classes[", arrIndex, "].ClassUri")));
    }

    function execute() internal override {
        bytes memory encodedData = abi.encode(className, claimable, classUri);ClassName

        vm.broadcast(deployerPrivateKey);
        classesImplementation.createClassType(encodedData);
    }
}
