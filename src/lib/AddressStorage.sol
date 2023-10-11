pragma solidity ^0.8.19;
// SPDX-License-Identifier: MIT

import {OwnableUpgradeable} from "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ERC1967Proxy} from "openzeppelin-contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {CharacterSheetsImplementation} from "../implementations/CharacterSheetsImplementation.sol";
import {ClassesImplementation} from "../implementations/ClassesImplementation.sol";
import {ExperienceImplementation} from "../implementations/ExperienceImplementation.sol";
import {ItemsImplementation} from "../implementations/ItemsImplementation.sol";
import {EligibilityAdaptor} from "../adaptors/EligibilityAdaptor.sol";
import {ClassLevelAdaptor} from "../adaptors/ClassLevelAdaptor.sol";
import {ItemsManagerImplementation} from "../implementations/ItemsManagerImplementation.sol";

import {IERC165} from "openzeppelin-contracts/utils/introspection/IERC165.sol";

import {Errors} from "./Errors.sol";

// import "forge-std/console2.sol";

contract AddressStorage is OwnableUpgradeable {
    // implementation addresses
    address public characterSheetsImplementation;
    address public itemsImplementation;
    address public classesImplementation;
    address public erc6551Registry;
    address public erc6551AccountImplementation;
    address public experienceImplementation;
    address public eligibilityAdaptorImplementation;
    address public classLevelAdaptorImplementation;
    address public itemsManagerImplementation;

    //hats addresses
    address public hatsContract;
    address public hatsModuleFactory;
    address public characterHatsEligibilityModule;
    address public playerHatsEligibilityModule;
    address public hatsAdaptorImplementation;

    // update events
    event CharacterSheetsUpdated(address newCharacterSheets);
    event ExperienceUpdated(address newExperience);
    event ItemsUpdated(address newItems);
    event RegistryUpdated(address newRegistry);
    event ERC6551AccountImplementationUpdated(address newImplementation);
    event ClassesImplementationUpdated(address newClasses);
    event EligibilityAdaptorUpdated(address newAdaptor);
    event ClassLevelAdaptorUpdated(address newAdaptor);
    event HatsAdaptorUpdated(address newHatsAdaptor);
    event ItemsManagerUpdated(address newItemsManager);
}
