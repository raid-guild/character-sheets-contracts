pragma solidity ^0.8.20;
// SPDX-License-Identifier: MIT

import {UUPSUpgradeable} from "openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {IHatsAdaptor} from "../interfaces/IHatsAdaptor.sol";

import {Errors} from "../lib/Errors.sol";

import "../lib/Structs.sol";

// import "forge-std/console2.sol";

contract ClonesAddressStorage is UUPSUpgradeable {
    //cloned contracts
    ClonesAddresses internal _clones;

    // update events
    event CharacterSheetCloneUpdated(address newCharacterSheetClone);
    event ItemsCloneUpdated(address newItemsClone);
    event ClassesCloneUpdated(address newClassesClone);
    event ExperienceCloneUpdated(address newExperienceClone);
    event CharacterEligibilityAdaptorCloneUpdated(address newCharacterEligibilityAdaptorCloneModule);
    event ClassLevelAdaptorCloneUpdated(address newClassLevelAdaptorClone);
    event ItemsManagerCloneUpdated(address newItemsManagerClone);
    event HatsAdaptorCloneUpdated(address newHatsAdaptorClone);
    event TopHatIdUpdated(uint256 _topHatId);
    event AdminIdUpdated(uint256 _adminId);
    event DungeonMasterIdUpdated(uint256 _dungeonMasterId);
    event PlayertIdUpdated(uint256 _playertId);
    event CharacterIdUpdated(uint256 _characterId);

    modifier onlyAdmin() {
        if (!IHatsAdaptor(_clones.hatsAdaptorClone).isAdmin(msg.sender)) {
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

    function updateCharacterSheetsClone(address newCharacterSheetsClone) external onlyAdmin {
        _clones.characterSheetsClone = newCharacterSheetsClone;
        emit CharacterSheetCloneUpdated(newCharacterSheetsClone);
    }

    function updateItemsClone(address _itemsClone) external onlyAdmin {
        _clones.itemsClone = _itemsClone;
        emit ItemsCloneUpdated(_itemsClone);
    }

    function updateExperienceClone(address _experienceClone) external onlyAdmin {
        _clones.experienceClone = _experienceClone;
        emit ExperienceCloneUpdated(_experienceClone);
    }

    function updateClassesClone(address _newClasses) external onlyAdmin {
        _clones.classesClone = _newClasses;
        emit ClassesCloneUpdated(_newClasses);
    }

    function updateCharacterEligibilityAdaptorClone(address _newCharacterEligibilityAdaptor) external onlyAdmin {
        _clones.characterEligibilityAdaptorClone = _newCharacterEligibilityAdaptor;
        emit CharacterEligibilityAdaptorCloneUpdated(_newCharacterEligibilityAdaptor);
    }

    function updateClassLevelAdaptorClone(address _newClassLevelAdaptor) external onlyAdmin {
        _clones.classLevelAdaptorClone = _newClassLevelAdaptor;
        emit ClassLevelAdaptorCloneUpdated(_newClassLevelAdaptor);
    }

    function updateHatsAdaptorClone(address _newHatsAdaptor) external onlyAdmin {
        _clones.hatsAdaptorClone = _newHatsAdaptor;

        emit HatsAdaptorCloneUpdated(_newHatsAdaptor);
    }

    function updateItemsManagerClone(address _newItemsManager) external onlyAdmin {
        _clones.itemsManagerClone = _newItemsManager;
        emit ItemsManagerCloneUpdated(_newItemsManager);
    }

    function characterSheetsClone() public view returns (address) {
        return _clones.characterSheetsClone;
    }

    function itemsClone() public view returns (address) {
        return _clones.itemsClone;
    }

    function itemsManagerClone() public view returns (address) {
        return _clones.itemsManagerClone;
    }

    function classesClone() public view returns (address) {
        return _clones.classesClone;
    }

    function experienceClone() public view returns (address) {
        return _clones.experienceClone;
    }

    function characterEligibilityAdaptorClone() public view returns (address) {
        return _clones.characterEligibilityAdaptorClone;
    }

    function classLevelAdaptorClone() public view returns (address) {
        return _clones.classLevelAdaptorClone;
    }

    function hatsAdaptorClone() public view returns (address) {
        return _clones.hatsAdaptorClone;
    }

    function _initClones(bytes calldata encodedClonesAddresses) internal {
        (
            _clones.characterSheetsClone,
            _clones.itemsClone,
            _clones.itemsManagerClone,
            _clones.classesClone,
            _clones.experienceClone
        ) = abi.decode(encodedClonesAddresses, (address, address, address, address, address));
    }

    function _initAdaptors(bytes calldata encodedAdaptorAddresses) internal {
        (_clones.characterEligibilityAdaptorClone, _clones.classLevelAdaptorClone, _clones.hatsAdaptorClone) =
            abi.decode(encodedAdaptorAddresses, (address, address, address));
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyAdmin {}
}
