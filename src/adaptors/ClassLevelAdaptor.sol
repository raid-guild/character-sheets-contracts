// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {ERC165} from "openzeppelin-contracts/utils/introspection/ERC165.sol";
import {IClassLevelAdaptor} from "../interfaces/IClassLevelAdaptor.sol";
import {UUPSUpgradeable} from "openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import {IERC1155} from "openzeppelin-contracts/token/ERC1155/IERC1155.sol";
import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import {Errors} from "../lib/Errors.sol";

/**
 * @title Class Level Adaptor
 * @author MrDeadCe11
 * @notice This is an adaptor that allows the classesImplementation to check the requirements to level a class
 * @dev any variation to this contract must implement the levelRequirementsMet and getExperienceForNextLevel functions
 */

contract ClassLevelAdaptor is IClassLevelAdaptor, ERC165, Initializable, OwnableUpgradeable, UUPSUpgradeable {
    /**
     * @notice erc651 interfaceId
     * @dev (this.levelRequirementsMet.selector ^ this.getExperienceForNextLevel.selector ^ this.supportsInterface.selector)
     */
    bytes4 public constant INTERFACE_ID = 0xfe211eb1;

    uint256 public constant MAX_LEVEL = 20; // Maximum level
    uint256[20] private _experiencePoints; // Array to store XP for each level

    address public classesContract;
    address public experienceContract;

    event ClassesContractUpdated(address newClassesContract);
    event ExperienceContractUpdated(address newExperienceContract);

    constructor() {
        _disableInitializers();
    }

    function initialize(address _classesContract, address _experienceContract) external initializer {
        _experiencePoints[0] = 0;
        _experiencePoints[1] = 300 * 10 ** 18;
        _experiencePoints[2] = 900 * 10 ** 18;
        _experiencePoints[3] = 2700 * 10 ** 18;
        _experiencePoints[4] = 6500 * 10 ** 18;
        _experiencePoints[5] = 14000 * 10 ** 18;
        _experiencePoints[6] = 23000 * 10 ** 18;
        _experiencePoints[7] = 34000 * 10 ** 18;
        _experiencePoints[8] = 48000 * 10 ** 18;
        _experiencePoints[9] = 64000 * 10 ** 18;
        _experiencePoints[10] = 85000 * 10 ** 18;
        _experiencePoints[11] = 100000 * 10 ** 18;
        _experiencePoints[12] = 120000 * 10 ** 18;
        _experiencePoints[13] = 140000 * 10 ** 18;
        _experiencePoints[14] = 165000 * 10 ** 18;
        _experiencePoints[15] = 195000 * 10 ** 18;
        _experiencePoints[16] = 225000 * 10 ** 18;
        _experiencePoints[17] = 265000 * 10 ** 18;
        _experiencePoints[18] = 305000 * 10 ** 18;
        _experiencePoints[19] = 355000 * 10 ** 18;

        classesContract = _classesContract;
        experienceContract = _experienceContract;
        __Ownable_init();
    }

    function updateClassesContract(address newClassesContract) public onlyOwner {
        classesContract = newClassesContract;
        emit ClassesContractUpdated(newClassesContract);
    }

    function updateExperienceContract(address newExperienceContract) public onlyOwner {
        experienceContract = newExperienceContract;
        emit ExperienceContractUpdated(newExperienceContract);
    }

    function levelRequirementsMet(address account, uint256 classId) public view returns (bool) {
        // checks the number of class tokens held by account.  1 token = level 0.
        uint256 currentLevel = IERC1155(classesContract).balanceOf(account, classId);
        if (currentLevel == 0) {
            revert Errors.InvalidClassLevel();
        }

        //current experience not locked in a class
        uint256 currentExp = IERC20(experienceContract).balanceOf(account);

        // check that the account holds the correct amount of exp to claim the next level + the amount already locked.  since 1 token = level 0.
        return getExperienceForNextLevel(currentLevel) <= currentExp;
    }

    function getExpForLevel(uint256 desiredLevel) public view returns (uint256) {
        return _experiencePoints[desiredLevel];
    }

    function getLockedExperience(uint256 currentLevel) public view returns (uint256) {
        if (currentLevel == 0) {
            revert Errors.InvalidClassLevel();
        }
        return _experiencePoints[currentLevel - 1];
    }

    function getExperienceForNextLevel(uint256 currentLevel) public view returns (uint256) {
        if (currentLevel >= MAX_LEVEL) {
            revert Errors.InvalidClassLevel();
        }
        return _experiencePoints[currentLevel] - getLockedExperience(currentLevel);
    }

    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        return interfaceId == 0x01ffc9a7 || interfaceId == INTERFACE_ID || super.supportsInterface(interfaceId);
    }

    // solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
