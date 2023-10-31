pragma solidity ^0.8.20;
// SPDX-License-Identifier: MIT

import {UUPSUpgradeable} from "openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {IHatsAdaptor} from "../interfaces/IHatsAdaptor.sol";

import {Errors} from "../lib/Errors.sol";
//solhint-disable-next-line
import "../lib/Structs.sol";

// import "forge-std/console2.sol";

contract ClonesAddressStorageImplementation is UUPSUpgradeable {
    //cloned contracts
    ClonesAddresses internal _clones;

    // update events
    event CharacterSheetUpdated(address newCharacterSheet);
    event ItemsUpdated(address newItems);
    event ClassesUpdated(address newClasses);
    event ExperienceUpdated(address newExperience);
    event CharacterEligibilityAdaptorUpdated(address newCharacterEligibilityAdaptorModule);
    event ClassLevelAdaptorUpdated(address newClassLevelAdaptor);
    event ItemsManagerUpdated(address newItemsManager);
    event HatsAdaptorUpdated(address newHatsAdaptor);
    event TopHatIdUpdated(uint256 _topHatId);
    event AdminIdUpdated(uint256 _adminId);
    event GameMasterIdUpdated(uint256 _gameMasterId);
    event PlayertIdUpdated(uint256 _playertId);
    event CharacterIdUpdated(uint256 _characterId);

    modifier onlyAdmin() {
        if (!IHatsAdaptor(_clones.hatsAdaptor).isAdmin(msg.sender)) {
            revert Errors.CallerNotApproved();
        }
        _;
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(bytes calldata encodedClonesAddresses, bytes calldata encodedAdaptorAddresses)
        external
        initializer
    {
        __UUPSUpgradeable_init();
        _initClones(encodedClonesAddresses);
        _initAdaptors(encodedAdaptorAddresses);
    }

    function updateCharacterSheets(address newCharacterSheets) external onlyAdmin {
        _clones.characterSheets = newCharacterSheets;
        emit CharacterSheetUpdated(newCharacterSheets);
    }

    function updateItems(address _items) external onlyAdmin {
        _clones.items = _items;
        emit ItemsUpdated(_items);
    }

    function updateExperience(address _experience) external onlyAdmin {
        _clones.experience = _experience;
        emit ExperienceUpdated(_experience);
    }

    function updateClasses(address _newClasses) external onlyAdmin {
        _clones.classes = _newClasses;
        emit ClassesUpdated(_newClasses);
    }

    function updateCharacterEligibilityAdaptor(address _newCharacterEligibilityAdaptor) external onlyAdmin {
        _clones.characterEligibilityAdaptor = _newCharacterEligibilityAdaptor;
        emit CharacterEligibilityAdaptorUpdated(_newCharacterEligibilityAdaptor);
    }

    function updateClassLevelAdaptor(address _newClassLevelAdaptor) external onlyAdmin {
        _clones.classLevelAdaptor = _newClassLevelAdaptor;
        emit ClassLevelAdaptorUpdated(_newClassLevelAdaptor);
    }

    function updateHatsAdaptor(address _newHatsAdaptor) external onlyAdmin {
        _clones.hatsAdaptor = _newHatsAdaptor;

        emit HatsAdaptorUpdated(_newHatsAdaptor);
    }

    function updateItemsManager(address _newItemsManager) external onlyAdmin {
        _clones.itemsManager = _newItemsManager;
        emit ItemsManagerUpdated(_newItemsManager);
    }

    function characterSheets() public view returns (address) {
        return _clones.characterSheets;
    }

    function items() public view returns (address) {
        return _clones.items;
    }

    function itemsManager() public view returns (address) {
        return _clones.itemsManager;
    }

    function classes() public view returns (address) {
        return _clones.classes;
    }

    function experience() public view returns (address) {
        return _clones.experience;
    }

    function characterEligibilityAdaptor() public view returns (address) {
        return _clones.characterEligibilityAdaptor;
    }

    function classLevelAdaptor() public view returns (address) {
        return _clones.classLevelAdaptor;
    }

    function hatsAdaptor() public view returns (address) {
        return _clones.hatsAdaptor;
    }

    function _initClones(bytes calldata encodedClonesAddresses) internal {
        (_clones.characterSheets, _clones.items, _clones.itemsManager, _clones.classes, _clones.experience) =
            abi.decode(encodedClonesAddresses, (address, address, address, address, address));
    }

    function _initAdaptors(bytes calldata encodedAdaptorAddresses) internal {
        (_clones.characterEligibilityAdaptor, _clones.classLevelAdaptor, _clones.hatsAdaptor) =
            abi.decode(encodedAdaptorAddresses, (address, address, address));
    }

    //solhint-disable-next-line
    function _authorizeUpgrade(address newImplementation) internal override onlyAdmin {
        //empty block
    }
}
