pragma solidity ^0.8.19;
// SPDX-License-Identifier: MIT

import {OwnableUpgradeable} from "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";

//solhint-disable-next-line
import "./lib/Structs.sol";

// import "forge-std/console2.sol";

contract ImplementationAddressStorage is Initializable, OwnableUpgradeable {
    ImplementationAddresses internal _implementationsAddresses;
    AdaptorImplementations internal _adaptors;

    // update events
    event CharacterSheetsUpdated(address newCharacterSheets);
    event ExperienceUpdated(address newExperience);
    event ItemsUpdated(address newItems);
    event RegistryUpdated(address newRegistry);
    event ERC6551AccountImplementationUpdated(address newImplementation);
    event ClassesImplementationUpdated(address newClasses);
    event MolochV2EligibilityAdaptorUpdated(address newAdaptor);
    event MolochV3EligibilityAdaptorUpdated(address newAdaptor);
    event ClassLevelAdaptorUpdated(address newAdaptor);
    event HatsAdaptorUpdated(address newHatsAdaptor);
    event ItemsManagerUpdated(address newItemsManager);
    event HatsContractUpdated(address newHatsContract);
    event HatsModuleFactoryUpdated(address newHatsModule);
    event AdminHatsEligibilityModuleUpdated(address newAdminModule);
    event GameMasterHatsEligibilityModuleUpdated(address newGameMasterModule);
    event PlayerHatsEligibilityModuleUpdated(address newPlayerModule);
    event CharacterHatsEligibilityModuleUpdated(address newCharacterModule);
    event CloneAddressStorageUpdated(address newCloneAddressStorage);

    function initialize(
        bytes calldata encodedImplementationAddresses,
        bytes calldata encodedModuleAddresses,
        bytes calldata encodedAdaptorAddresses,
        bytes calldata encodedExternalAddresses
    ) external initializer {
        __Ownable_init_unchained(msg.sender);
        _initImplementations(encodedImplementationAddresses);
        _initModules(encodedModuleAddresses);
        _initAdaptors(encodedAdaptorAddresses);
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

    function updateMolochV2EligibilityAdaptorImplementation(address newCharacterEligibilityAdaptor)
        external
        onlyOwner
    {
        _adaptors.molochV2EligibilityAdaptorImplementation = newCharacterEligibilityAdaptor;
        emit MolochV2EligibilityAdaptorUpdated(newCharacterEligibilityAdaptor);
    }

    function updateMolochV3EligibilityAdaptorImplementation(address newCharacterEligibilityAdaptor)
        external
        onlyOwner
    {
        _adaptors.molochV3EligibilityAdaptorImplementation = newCharacterEligibilityAdaptor;
        emit MolochV3EligibilityAdaptorUpdated(newCharacterEligibilityAdaptor);
    }

    function updateClassLevelAdaptorImplementation(address newClassLevelAdaptor) external onlyOwner {
        _adaptors.classLevelAdaptorImplementation = newClassLevelAdaptor;
        emit ClassLevelAdaptorUpdated(newClassLevelAdaptor);
    }

    function updateHatsAdaptorImplementation(address newHatsAdaptor) external onlyOwner {
        _adaptors.hatsAdaptorImplementation = newHatsAdaptor;

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

    function updateGameMasterHatsEligibilityModule(address newGameMasterHatsEligibilityModule) external onlyOwner {
        _implementationsAddresses.gameMasterHatsEligibilityModule = newGameMasterHatsEligibilityModule;

        emit GameMasterHatsEligibilityModuleUpdated(newGameMasterHatsEligibilityModule);
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

    function molochV2EligibilityAdaptorImplementation() public view returns (address) {
        return _adaptors.molochV2EligibilityAdaptorImplementation;
    }

    function molochV3EligibilityAdaptorImplementation() public view returns (address) {
        return _adaptors.molochV3EligibilityAdaptorImplementation;
    }

    function classLevelAdaptorImplementation() public view returns (address) {
        return _adaptors.classLevelAdaptorImplementation;
    }

    function hatsAdaptorImplementation() public view returns (address) {
        return _adaptors.hatsAdaptorImplementation;
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

    function gameMasterHatsEligibilityModule() public view returns (address) {
        return _implementationsAddresses.gameMasterHatsEligibilityModule;
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

    function _initModules(bytes calldata encodedModuleAddresses) internal {
        (
            _implementationsAddresses.adminHatsEligibilityModule,
            _implementationsAddresses.gameMasterHatsEligibilityModule,
            _implementationsAddresses.playerHatsEligibilityModule,
            _implementationsAddresses.characterHatsEligibilityModule
        ) = abi.decode(encodedModuleAddresses, (address, address, address, address));
    }

    function _initAdaptors(bytes calldata encodedAdaptorAddresses) internal {
        (
            _adaptors.hatsAdaptorImplementation,
            _adaptors.molochV2EligibilityAdaptorImplementation,
            _adaptors.molochV3EligibilityAdaptorImplementation,
            _adaptors.classLevelAdaptorImplementation
        ) = abi.decode(encodedAdaptorAddresses, (address, address, address, address));
    }

    function _initExternalAddresses(bytes calldata encodedExternalAddresses) internal {
        (
            _implementationsAddresses.erc6551Registry,
            _implementationsAddresses.hatsContract,
            _implementationsAddresses.hatsModuleFactory
        ) = abi.decode(encodedExternalAddresses, (address, address, address));
    }
}
