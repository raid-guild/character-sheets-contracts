// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {CharacterSheetsImplementation} from "../src/implementations/CharacterSheetsImplementation.sol";
import {Moloch} from "../src/mocks/MockMoloch.sol";
import {BaseDeployer} from "./BaseDeployer.sol";
import {BaseExecutor} from "./BaseExecutor.sol";
import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

contract ExecuteCharacterSheetsImplementation is BaseExecutor {
    using stdJson for string;

    CharacterSheetsImplementation public sheetsImp;
    address public characterSheets;
    string public characterName;
    string public sheetUri;
    address public memberAddress;
    Moloch public dao;

    function loadBaseData(string memory json, string memory targetEnv) internal override {
        characterSheets = json.readAddress(string(abi.encodePacked(".", targetEnv, ".CreatedCharacterSheet")));
        sheetsImp = CharacterSheetsImplementation(characterSheets);
        console2.log("ARR INDEX: ", arrIndex);
        characterName =
            json.readString(string(abi.encodePacked(".", targetEnv, ".Characters[", arrIndex, "].CharacterName")));
        sheetUri = json.readString(string(abi.encodePacked(".", targetEnv, ".Characters[", arrIndex, "].uri")));
        memberAddress =
            json.readAddress(string(abi.encodePacked(".", targetEnv, ".Characters[", arrIndex, "].MemberAddress")));
        address _daoAddress = json.readAddress(string(abi.encodePacked(".", targetEnv, ".Dao")));
        dao = Moloch(_daoAddress);
    }

    function execute() internal override {
        Moloch.Member memory member = dao.members(memberAddress);

        if (member.shares < 100 && block.chainid == 11155111) {
            vm.broadcast(deployerPrivateKey);
            dao.addMember(memberAddress);
        }

        console2.log("SHEET URI: ", sheetUri);

        bytes memory encodedData = abi.encode(characterName, sheetUri);

        vm.broadcast(deployerPrivateKey);
        uint256 tokenId = sheetsImp.rollCharacterSheet(memberAddress, encodedData);
        console.log("Character Id:", tokenId);
    }
}

contract DeployCharacterSheetsImplementation is BaseDeployer {
    using stdJson for string;

    CharacterSheetsImplementation public characterSheetsImplementation;

    function deploy() internal override returns (address) {
        vm.startBroadcast(deployerPrivateKey);

        characterSheetsImplementation = new CharacterSheetsImplementation();

        vm.stopBroadcast();

        return address(characterSheetsImplementation);
    }
}
