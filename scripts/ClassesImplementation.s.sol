// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
//solhint-disable

import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

import {ClassesImplementation} from "../src/implementations/ClassesImplementation.sol";

import {BaseDeployer} from "./BaseDeployer.sol";
import {BaseExecutor} from "./BaseExecutor.sol";

contract DeployClassesImplementation is BaseDeployer {
    using stdJson for string;

    ClassesImplementation public classesImplementation;

    function deploy() internal override returns (address) {
        vm.startBroadcast(deployerPrivateKey);

        address newContractAddress = getDeploymentAddress(type(ClassesImplementation).creationCode);

        if (!isContract(newContractAddress)) {
            classesImplementation = new ClassesImplementation{salt: SALT}();
            assert(address(classesImplementation) == newContractAddress);
        }

        vm.stopBroadcast();

        return newContractAddress;
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
        claimable = json.readBool(string(abi.encodePacked(".", targetEnv, ".Classes[", arrIndex, "].Claimable")));
        classesImplementation = ClassesImplementation(classes);
        console2.log("ARR INDEX: ", arrIndex);
        className = json.readString(string(abi.encodePacked(".", targetEnv, ".Classes[", arrIndex, "].ClassName")));
        classUri = json.readString(string(abi.encodePacked(".", targetEnv, ".Classes[", arrIndex, "].ClassUri")));
    }

    function execute() internal override {
        bytes memory encodedData = abi.encode(className, claimable, classUri);

        vm.broadcast(deployerPrivateKey);
        classesImplementation.createClassType(encodedData);
    }
}
