// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
pragma abicoder v2;

import "forge-std/Test.sol";

import "../src/lib/Structs.sol";
import {Errors} from "../src/lib/Errors.sol";
import {SetUp} from "./helpers/SetUp.sol";

contract HatsAdaptor is Test, SetUp {
    /**
     * HATS ADDRESSES
     *        1.  address hats,
     *        2.  address hatsModuleFactory,
     *        3.  address adminHatEligibilityModule
     *        4.  address dungeonMasterEligibilityModuleImplementation
     *        5.  address playerHatEligibilityModuleImplementation
     *        6.  address characterHatEligibilityModuleImplementation
     *        7.  address[]  admins
     *        8.  address[] dungeon masters
     *        9.  address character sheets
     *        10.  address erc6551 registry
     *        11. address erc6551 account implementation
     */

    /**
     * HATS STRINGS
     *        1.  string _baseImgUri
     *        2.  string topHatDescription
     *        3.  string adminUri
     *        4.  string adminDescription
     *        5.  string dungeonMasterUri
     *        6.  string dungeonMasterDescription
     *        7.  string playerUri
     *        8.  string playerDescription
     *        9.  string characterUri
     *        10. string characterDescription
     */

    function testInitializeHatsAdaptor() public {
        bytes memory encodedHatsAddresses = abi.encode(
            address(hats),
            address(hatsModuleFactory),
            storedImp.adminHatEligibilityModuleImplementation,
            storedImp.dungeonMasterHatEligibilityModuleImplementation,
            storedImp.playerHatEligibilityModuleImplementation,
            storedImp.characterHatEligibilityModuleImplementation,
            adminArray,
            dungeonMastersArray,
            storedCreated.characterSheets,
            address(erc6551Registry),
            address(erc6551Implementation)
        );

        bytes memory encodedHatsStrings = abi.encode(
            "test_hats_base_img",
            "test tophat description",
            "test_admin_uri",
            "test_admin_description",
            "test_dungeon_uri",
            "test_dungeon_description",
            "test_player_uri",
            "test_player_description",
            "test_character_uri",
            "test_character_description"
        );
        hatsAdaptor.initialize(admin, encodedHatsAddresses, encodedHatsStrings);
    }
}
