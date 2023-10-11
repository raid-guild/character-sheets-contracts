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

import {IHatsAdaptor} from "../interfaces/IHatsAdaptor.sol";

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
    address public hatsAdaptorImplementation;

    //hats addresses
    address public hatsContract;
    address public hatsModuleFactory;
    //eligibility modules
    address public adminHatsEligibilityModule;
    address public dungeonMasterHatsEligibilityModule;
    address public playerHatsEligibilityModule;
    address public characterHatsEligibilityModule;

    //cloned contracts
    address public characterSheetsClone;
    address public itemsClone;
    address public classesClone;
    address public experienceClone;
    address public eligibilityAdaptorClone;
    address public classLevelAdaptorClone;
    address public itemsManagerClone;
    address public hatsAdaptorClone;

    //hats ids
    uint256 public topHatId;
    uint256 public adminHatId;
    uint256 public dungeonMasterHatId;
    uint256 public playerHatId;
    uint256 public characterHatId;

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
    event HatsContractUpdated(address newHatsContract);
    event HatsModuleFactoryUpdated(address newHatsModule);
    event AdminHatsEligibilityModuleUpdated(address newAdminModule);
    event DungeonMasterHatsEligibilityModuleUpdated(address newDungeonMasterModule);
    event PlayerHatsEligibilityModuleUpdated(address newPlayerModule);
    event CharacterHatsEligibilityModuleUpdated(address newCharacterModule);

    constructor() {
        _disableInitializers();
    }

    function initialize() external initializer {
        __Context_init_unchained();
        __Ownable_init_unchained();
    }

    function updateCharacterSheetsImplementation(address _sheetImplementation) external onlyOwner {
        characterSheetsImplementation = _sheetImplementation;
        emit CharacterSheetsUpdated(_sheetImplementation);
    }

    function updateItemsImplementation(address _itemsImplementation) external onlyOwner {
        itemsImplementation = _itemsImplementation;
        emit ItemsUpdated(_itemsImplementation);
    }

    function updateExperienceImplementation(address _experienceImplementation) external onlyOwner {
        experienceImplementation = _experienceImplementation;
        emit ExperienceUpdated(_experienceImplementation);
    }

    function updateERC6551Registry(address _newRegistry) external onlyOwner {
        erc6551Registry = _newRegistry;
        emit RegistryUpdated(erc6551Registry);
    }

    function updateERC6551AccountImplementation(address _newImplementation) external onlyOwner {
        erc6551AccountImplementation = _newImplementation;
        emit ERC6551AccountImplementationUpdated(_newImplementation);
    }

    function updateClassesImplementation(address _newClasses) external onlyOwner {
        classesImplementation = _newClasses;
        emit ClassesImplementationUpdated(classesImplementation);
    }

    function updateEligibilityAdaptorImplementation(address _newEligibilityAdaptor) external onlyOwner {
        eligibilityAdaptorImplementation = _newEligibilityAdaptor;
        emit EligibilityAdaptorUpdated(_newEligibilityAdaptor);
    }

    function updateClassLevelAdaptorImplementation(address _newClassLevelAdaptor) external onlyOwner {
        classLevelAdaptorImplementation = _newClassLevelAdaptor;
        emit ClassLevelAdaptorUpdated(_newClassLevelAdaptor);
    }

    function updateHatsAdaptorImplementation(address _newHatsAdaptor) external onlyOwner {
        hatsAdaptorImplementation = _newHatsAdaptor;

        emit HatsAdaptorUpdated(_newHatsAdaptor);
    }

    function updateItemsManagerImplementation(address _newItemsManager) external onlyOwner {
        itemsManagerImplementation = _newItemsManager;
        emit ItemsManagerUpdated(_newItemsManager);
    }

    function updateHatsContract(address newHatsContract) external onlyOwner {
        hatsContract = newHatsContract;

        emit HatsContractUpdated(_newHatsContract);
    }

    function updateHatsModuleFactory(address newHatsModuleFactory) external onlyOwner {
        hatsModuleFactory = newHatsModuleFactory;

        emit HatsModuleFactoryUpdated(_newHatsModuleFactory);
    }

    function updateAdminHatsEligibilityModule(address newAdminHatsEligibilityModule) external onlyOwner {
        adminHatsEligibilityModule = newAdminHatsEligibilityModule;

        emit AdminHatsEligibilityModuleUpdated(newAdminHatsEligibilityModule);
    }

    function updateDungeonMasterHatsEligibilityModule(address newDungeonMasterHatsEligibilityModule)
        external
        onlyOwner
    {
        dungeonMasterHatsEligibilityModule = newDungeonMasterHatsEligibilityModule;

        emit DungeonMasterHatsEligibilityModuleUpdated(newDungeonMasterHatsEligibilityModule);
    }

    function updatePlayerHatsEligibilityModule(address newPlayerHatsEligibilityModule) external onlyOwner {
        playerHatsEligibilityModule = newPlayerHatsEligibilityModule;

        emit PlayerHatsEligibilityModuleUpdated(newPlayerHatsEligibilityModule);
    }

    function updateCharacterHatsEligibilityModule(address newCharacterHatsEligibilityModule) external onlyOwner {
        characterHatsEligibilityModule = newCharacterHatsEligibilityModule;

        emit CharacterHatsEligibilityModuleUpdated(newCharacterHatsEligibilityModule);
    }
}
