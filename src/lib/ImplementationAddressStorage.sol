pragma solidity ^0.8.19;
// SPDX-License-Identifier: MIT

import {OwnableUpgradeable} from "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import {Errors} from "./Errors.sol";

// import "forge-std/console2.sol";

contract ImplementationAddressStorage is Initializable, OwnableUpgradeable {
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
    address public cloneAddressStorage;

    //hats addresses
    address public hatsContract;
    address public hatsModuleFactory;

    //eligibility modules
    address public adminHatsEligibilityModule;
    address public dungeonMasterHatsEligibilityModule;
    address public playerHatsEligibilityModule;
    address public characterHatsEligibilityModule;

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
    event CloneAddressStorageUpdated(address newCloneAddressStorage);

    constructor() {
        _disableInitializers();
    }

    function initialize(bytes calldata encodedImplementationAddresses) external initializer {
        __Ownable_init_unchained();

        (
            characterSheetsImplementation,
            itemsImplementation,
            classesImplementation,
            erc6551Registry,
            erc6551AccountImplementation,
            experienceImplementation,
            eligibilityAdaptorImplementation,
            classLevelAdaptorImplementation,
            itemsManagerImplementation,
            hatsAdaptorImplementation,
            cloneAddressStorage,
            hatsContract,
            hatsModuleFactory,
            adminHatsEligibilityModule,
            dungeonMasterHatsEligibilityModule,
            playerHatsEligibilityModule,
            characterHatsEligibilityModule
        ) = abi.decode(
            encodedImplementationAddresses,
            (
                address,
                address,
                address,
                address,
                address,
                address,
                address,
                address,
                address,
                address,
                address,
                address,
                address,
                address,
                address,
                address,
                address
            )
        );
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

        emit HatsContractUpdated(newHatsContract);
    }

    function updateHatsModuleFactory(address newHatsModuleFactory) external onlyOwner {
        hatsModuleFactory = newHatsModuleFactory;

        emit HatsModuleFactoryUpdated(newHatsModuleFactory);
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

    function updateCloneAddressStorage(address newCloneAddressStorage) external onlyOwner {
        cloneAddressStorage = newCloneAddressStorage;

        emit CloneAddressStorageUpdated(newCloneAddressStorage);
    }
}
