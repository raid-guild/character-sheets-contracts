// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC165} from "openzeppelin-contracts/utils/introspection/ERC165.sol";
import {UUPSUpgradeable} from "openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Initializable} from "openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import {Errors} from "../lib/Errors.sol";

import {IClonesAddressStorage} from "../interfaces/IClonesAddressStorage.sol";
import {IHatsAdaptor} from "../interfaces/IHatsAdaptor.sol";

/**
 * @title Class Level Adaptor
 * @author MrDeadCe11
 * @notice This is an adaptor that allows the classesImplementation to check the requirements to level a class
 * @dev any variation to this contract must implement the levelRequirementsMet and getExperienceForNextLevel functions
 */
contract ClassLevelAdaptor is ERC165, Initializable, UUPSUpgradeable {
    /**
     * @notice erc651 interfaceId
     * @dev (this.levelRequirementsMet.selector ^ this.getExperienceForNextLevel.selector ^ this.supportsInterface.selector)
     */
    bytes4 public constant INTERFACE_ID = 0xfe211eb1;

    uint256 public constant MAX_LEVEL = 20; // Maximum level
    uint256[20] private _experiencePoints; // Array to store XP for each level

    IClonesAddressStorage public clones;

    event ClonesAddressStorageUpdated(address newClonesAddressStorage);

    modifier onlyAdmin() {
        if (!IHatsAdaptor(clones.hatsAdaptor()).isAdmin(msg.sender)) {
            revert Errors.AdminOnly();
        }
        _;
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(address _clonesAddressStorage) external initializer {
        _experiencePoints[0] = 0; // lvl 1
        _experiencePoints[1] = 300; // lvl 2  300xp to progress from lvl 1 to lvl to
        _experiencePoints[2] = 900; // lvl 3
        _experiencePoints[3] = 2700; // I think you see what's going on here
        _experiencePoints[4] = 6500;
        _experiencePoints[5] = 14000;
        _experiencePoints[6] = 23000;
        _experiencePoints[7] = 34000;
        _experiencePoints[8] = 48000;
        _experiencePoints[9] = 64000;
        _experiencePoints[10] = 85000;
        _experiencePoints[11] = 100000;
        _experiencePoints[12] = 120000;
        _experiencePoints[13] = 140000;
        _experiencePoints[14] = 165000;
        _experiencePoints[15] = 195000;
        _experiencePoints[16] = 225000;
        _experiencePoints[17] = 265000;
        _experiencePoints[18] = 305000;
        _experiencePoints[19] = 355000;

        clones = IClonesAddressStorage(_clonesAddressStorage);
    }

    function updateClonesAddressStorage(address newClonesAddressStorage) public onlyAdmin {
        clones = IClonesAddressStorage(newClonesAddressStorage);
        emit ClonesAddressStorageUpdated(newClonesAddressStorage);
    }

    function getExpForLevel(uint256 desiredLevel) public view returns (uint256) {
        return _experiencePoints[desiredLevel];
    }

    function getCurrentLevel(uint256 expAmount) public view returns (uint256 currentLevel) {
        if (expAmount >= _experiencePoints[19]) {
            currentLevel = 20;
        } else {
            for (uint256 i; i < _experiencePoints.length;) {
                if (_experiencePoints[i] <= expAmount && _experiencePoints[i + 1] > expAmount) {
                    currentLevel = i + 1;
                    break;
                }
                {
                    i++;
                }
            }
        }
    }

    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        return interfaceId == 0x01ffc9a7 || interfaceId == INTERFACE_ID || super.supportsInterface(interfaceId);
    }

    // solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address newImplementation) internal override onlyAdmin {}
}
