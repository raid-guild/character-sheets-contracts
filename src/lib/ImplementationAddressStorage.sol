pragma solidity ^0.8.19;
// SPDX-License-Identifier: MIT

import {OwnableUpgradeable} from "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import {Errors} from "./Errors.sol";

import "./Structs.sol";

// // import "forge-std/console2.sol";

contract ImplementationAddressStorage is Initializable, OwnableUpgradeable {
    ImplementationAddresses internal _implementationsAddresses;

    // update events
    event CharacterSheetsUpdated(address newCharacterSheets);
    event ExperienceUpdated(address newExperience);
    event ItemsUpdated(address newItems);
    event RegistryUpdated(address newRegistry);
    event ERC6551AccountImplementationUpdated(address newImplementation);
    event ClassesImplementationUpdated(address newClasses);
    event CharacterEligibilityAdaptorUpdated(address newAdaptor);
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

    function initialize(
        bytes calldata encodedImplementationAddresses,
        bytes calldata encodedAdaptorsAndMOduleAddresses,
        bytes calldata encodedExternalAddresses
    ) external initializer {
        __Ownable_init_unchained(msg.sender);
        _initImplementations(encodedImplementationAddresses);
        _initAdaptorsAndModules(encodedAdaptorsAndMOduleAddresses);
        _initExternalAddresses(encodedExternalAddresses);
    }

    function updateCharacterSheetsImplementation(address newSheetImplementation) external onlyOwner {
        _implementationsAddresses.characterSheetsImplementation = newSheetImplementation;
        emit CharacterSheetsUpdated(newSheetImplementation);
    }

    function updateItemsImplementation(address newItemsImplementation) external onlyOwner {
        _implementationsAddresses.itemsImplementation = newItemsImplementation;
        emit ItemsUpdated(newItemsImplementation);
    }

    function updateExperienceImplementation(address newExperienceImplementation) external onlyOwner {
        _implementationsAddresses.experienceImplementation = newExperienceImplementation;
        emit ExperienceUpdated(newExperienceImplementation);
    }

    function updateERC6551Registry(address newRegistry) external onlyOwner {
        _implementationsAddresses.erc6551Registry = newRegistry;
        emit RegistryUpdated(newRegistry);
    }

    function updateERC6551AccountImplementation(address newErc6551AccountImplementation) external onlyOwner {
        _implementationsAddresses.erc6551AccountImplementation = newErc6551AccountImplementation;
        emit ERC6551AccountImplementationUpdated(newErc6551AccountImplementation);
    }

    function updateClassesImplementation(address newClasses) external onlyOwner {
        _implementationsAddresses.classesImplementation = newClasses;
        emit ClassesImplementationUpdated(newClasses);
    }

    function updateCharacterEligibilityAdaptorImplementation(address newCharacterEligibilityAdaptor)
        external
        onlyOwner
    {
        _implementationsAddresses.characterEligibilityAdaptorImplementation = newCharacterEligibilityAdaptor;
        emit CharacterEligibilityAdaptorUpdated(newCharacterEligibilityAdaptor);
    }

    function updateClassLevelAdaptorImplementation(address newClassLevelAdaptor) external onlyOwner {
        _implementationsAddresses.classLevelAdaptorImplementation = newClassLevelAdaptor;
        emit ClassLevelAdaptorUpdated(newClassLevelAdaptor);
    }

    function updateHatsAdaptorImplementation(address newHatsAdaptor) external onlyOwner {
        _implementationsAddresses.hatsAdaptorImplementation = newHatsAdaptor;

        emit HatsAdaptorUpdated(newHatsAdaptor);
    }

    function updateItemsManagerImplementation(address newItemsManager) external onlyOwner {
        _implementationsAddresses.itemsManagerImplementation = newItemsManager;
        emit ItemsManagerUpdated(newItemsManager);
    }

    function updateHatsContract(address newHatsContract) external onlyOwner {
        _implementationsAddresses.hatsContract = newHatsContract;

        emit HatsContractUpdated(newHatsContract);
    }

    function updateHatsModuleFactory(address newHatsModuleFactory) external onlyOwner {
        _implementationsAddresses.hatsModuleFactory = newHatsModuleFactory;

        emit HatsModuleFactoryUpdated(newHatsModuleFactory);
    }

    function updateAdminHatsEligibilityModule(address newAdminHatsEligibilityModule) external onlyOwner {
        _implementationsAddresses.adminHatsEligibilityModule = newAdminHatsEligibilityModule;

        emit AdminHatsEligibilityModuleUpdated(newAdminHatsEligibilityModule);
    }

    function updateDungeonMasterHatsEligibilityModule(address newDungeonMasterHatsEligibilityModule)
        external
        onlyOwner
    {
        _implementationsAddresses.dungeonMasterHatsEligibilityModule = newDungeonMasterHatsEligibilityModule;

        emit DungeonMasterHatsEligibilityModuleUpdated(newDungeonMasterHatsEligibilityModule);
    }

    function updatePlayerHatsEligibilityModule(address newPlayerHatsEligibilityModule) external onlyOwner {
        _implementationsAddresses.playerHatsEligibilityModule = newPlayerHatsEligibilityModule;

        emit PlayerHatsEligibilityModuleUpdated(newPlayerHatsEligibilityModule);
    }

    function updateCharacterHatsEligibilityModule(address newCharacterHatsEligibilityModule) external onlyOwner {
        _implementationsAddresses.characterHatsEligibilityModule = newCharacterHatsEligibilityModule;

        emit CharacterHatsEligibilityModuleUpdated(newCharacterHatsEligibilityModule);
    }

    function updateCloneAddressStorage(address newCloneAddressStorage) external onlyOwner {
        _implementationsAddresses.cloneAddressStorage = newCloneAddressStorage;

        emit CloneAddressStorageUpdated(newCloneAddressStorage);
    }

    function characterSheetsImplementation() public view returns (address) {
        return _implementationsAddresses.characterSheetsImplementation;
    }

    function itemsImplementation() public view returns (address) {
        return _implementationsAddresses.itemsImplementation;
    }

    function classesImplementation() public view returns (address) {
        return _implementationsAddresses.classesImplementation;
    }

    function itemsManagerImplementation() public view returns (address) {
        return _implementationsAddresses.itemsManagerImplementation;
    }

    function experienceImplementation() public view returns (address) {
        return _implementationsAddresses.experienceImplementation;
    }

    function erc6551Registry() public view returns (address) {
        return _implementationsAddresses.erc6551Registry;
    }

    function erc6551AccountImplementation() public view returns (address) {
        return _implementationsAddresses.erc6551AccountImplementation;
    }

    function characterEligibilityAdaptorImplementation() public view returns (address) {
        return _implementationsAddresses.characterEligibilityAdaptorImplementation;
    }

    function classLevelAdaptorImplementation() public view returns (address) {
        return _implementationsAddresses.classLevelAdaptorImplementation;
    }

    function hatsAdaptorImplementation() public view returns (address) {
        return _implementationsAddresses.hatsAdaptorImplementation;
    }

    function cloneAddressStorage() public view returns (address) {
        return _implementationsAddresses.cloneAddressStorage;
    }

    function hatsContract() public view returns (address) {
        return _implementationsAddresses.hatsContract;
    }

    function hatsModuleFactory() public view returns (address) {
        return _implementationsAddresses.hatsModuleFactory;
    }

    function adminHatsEligibilityModule() public view returns (address) {
        return _implementationsAddresses.adminHatsEligibilityModule;
    }

    function dungeonMasterHatsEligibilityModule() public view returns (address) {
        return _implementationsAddresses.dungeonMasterHatsEligibilityModule;
    }

    function playerHatsEligibilityModule() public view returns (address) {
        return _implementationsAddresses.playerHatsEligibilityModule;
    }

    function characterHatsEligibilityModule() public view returns (address) {
        return _implementationsAddresses.characterHatsEligibilityModule;
    }

    function _initImplementations(bytes calldata encodedImplementationAddresses) internal {
        (
            _implementationsAddresses.characterSheetsImplementation,
            _implementationsAddresses.itemsImplementation,
            _implementationsAddresses.classesImplementation,
            _implementationsAddresses.experienceImplementation,
            _implementationsAddresses.cloneAddressStorage,
            _implementationsAddresses.itemsManagerImplementation,
            _implementationsAddresses.erc6551AccountImplementation
        ) = abi.decode(encodedImplementationAddresses, (address, address, address, address, address, address, address));
    }

    function _initAdaptorsAndModules(bytes calldata encodedAdaptorsAndModuleAddresses) internal {
        (
            _implementationsAddresses.adminHatsEligibilityModule,
            _implementationsAddresses.dungeonMasterHatsEligibilityModule,
            _implementationsAddresses.playerHatsEligibilityModule,
            _implementationsAddresses.characterHatsEligibilityModule,
            _implementationsAddresses.hatsAdaptorImplementation,
            _implementationsAddresses.characterEligibilityAdaptorImplementation,
            _implementationsAddresses.classLevelAdaptorImplementation
        ) = abi.decode(
            encodedAdaptorsAndModuleAddresses, (address, address, address, address, address, address, address)
        );
    }

    function _initExternalAddresses(bytes calldata encodedExternalAddresses) internal {
        (
            _implementationsAddresses.erc6551Registry,
            _implementationsAddresses.hatsContract,
            _implementationsAddresses.hatsModuleFactory
        ) = abi.decode(encodedExternalAddresses, (address, address, address));
    }
}
