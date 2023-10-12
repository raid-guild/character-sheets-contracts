pragma solidity ^0.8.19;
// SPDX-License-Identifier: MIT

import {UUPSUpgradeable} from "openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {IHatsAdaptor} from "../interfaces/IHatsAdaptor.sol";

import {Errors} from "./Errors.sol";

// import "forge-std/console2.sol";

contract ClonesAddressStorage is UUPSUpgradeable {
    //cloned contracts
    address public characterSheetsClone;
    address public itemsClone;
    address public itemsManagerClone;
    address public classesClone;
    address public experienceClone;
    address public eligibilityAdaptorClone;
    address public classLevelAdaptorClone;
    address public hatsAdaptorClone;

    // update events
    event CharacterSheetCloneUpdated(address newCharacterSheetClone);
    event ItemsCloneUpdated(address newItemsClone);
    event ClassesCloneUpdated(address newClassesClone);
    event ExperienceCloneUpdated(address newExperienceClone);
    event EligibilityAdaptorCloneUpdated(address newEligibilityAdaptorCloneModule);
    event ClassLevelAdaptorCloneUpdated(address newClassLevelAdaptorClone);
    event ItemsManagerCloneUpdated(address newItemsManagerClone);
    event HatsAdaptorCloneUpdated(address newHatsAdaptorClone);
    event TopHatIdUpdated(uint256 _topHatId);
    event AdminIdUpdated(uint256 _adminId);
    event DungeonMasterIdUpdated(uint256 _dungeonMasterId);
    event PlayertIdUpdated(uint256 _playertId);
    event CharacterIdUpdated(uint256 _characterId);

    modifier onlyAdmin() {
        if (!IHatsAdaptor(hatsAdaptorClone).isAdmin(msg.sender)) {
            revert Errors.CallerNotApproved();
        }
        _;
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(bytes calldata encodedClonesAddresses) external initializer {
        __UUPSUpgradeable_init();

        (
            characterSheetsClone,
            itemsClone,
            itemsManagerClone,
            classesClone,
            experienceClone,
            eligibilityAdaptorClone,
            classLevelAdaptorClone,
            hatsAdaptorClone
        ) = abi.decode(encodedClonesAddresses, (address, address, address, address, address, address, address, address));
    }

    function updateCharacterSheetsClone(address newCharacterSheetsClone) external onlyAdmin {
        characterSheetsClone = newCharacterSheetsClone;
        emit CharacterSheetCloneUpdated(newCharacterSheetsClone);
    }

    function updateItemsClone(address _itemsClone) external onlyAdmin {
        itemsClone = _itemsClone;
        emit ItemsCloneUpdated(_itemsClone);
    }

    function updateExperienceClone(address _experienceClone) external onlyAdmin {
        experienceClone = _experienceClone;
        emit ExperienceCloneUpdated(_experienceClone);
    }

    function updateClassesClone(address _newClasses) external onlyAdmin {
        classesClone = _newClasses;
        emit ClassesCloneUpdated(classesClone);
    }

    function updateEligibilityAdaptorClone(address _newEligibilityAdaptor) external onlyAdmin {
        eligibilityAdaptorClone = _newEligibilityAdaptor;
        emit EligibilityAdaptorCloneUpdated(_newEligibilityAdaptor);
    }

    function updateClassLevelAdaptorClone(address _newClassLevelAdaptor) external onlyAdmin {
        classLevelAdaptorClone = _newClassLevelAdaptor;
        emit ClassLevelAdaptorCloneUpdated(_newClassLevelAdaptor);
    }

    function updateHatsAdaptorClone(address _newHatsAdaptor) external onlyAdmin {
        hatsAdaptorClone = _newHatsAdaptor;

        emit HatsAdaptorCloneUpdated(_newHatsAdaptor);
    }

    function updateItemsManagerClone(address _newItemsManager) external onlyAdmin {
        itemsManagerClone = _newItemsManager;
        emit ItemsManagerCloneUpdated(_newItemsManager);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyAdmin {}
}
