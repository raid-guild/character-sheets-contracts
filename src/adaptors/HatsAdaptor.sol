// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {ERC165} from "openzeppelin-contracts/utils/introspection/ERC165.sol";
import {UUPSUpgradeable} from "openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import {IHats} from "hats-protocol/Interfaces/IHats.sol";
import {ERC1155HolderUpgradeable} from
    "openzeppelin-contracts-upgradeable/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";
import {IHatsEligibility} from "hats-protocol/Interfaces/IHatsEligibility.sol";

import {Errors} from "../lib/Errors.sol";
import {HatsData} from "../lib/Structs.sol";

/**
 * @title Hats Adaptor
 * @author MrDeadCe11
 * @notice This is an adaptor that allows the minting of hats to players and characters and also allows
 *  all contracts to check if any address is wearing the player or character hat.
 *
 * /**
 * struct HatsData {
 *     address hats;
 *     address characterHatEligibilityModule;
 *     address playerHatEligibilityModule;
 *     address hatsModuleFactory;
 *     uint256 adminHatId;
 *     uint256 playerHatId;
 *     uint256 characterHatId;
 * }
 */

contract HatsAdaptor is Initializable, OwnableUpgradeable, UUPSUpgradeable, ERC1155HolderUpgradeable {
    HatsData private _hatsData;

    event HatsAddressUpdated(address);
    event CharacterHatEligibilityModuleAddressUpdated(address);
    event PlayerHatEligibilityModuleAddressUpdated(address);
    event AdminHatIdUpdated(uint256);
    event DungeonMasterHatIdUpdated(uint256);
    event PlayerHatIdUpdated(uint256);
    event CharacterHatIdUpdated(uint256);

    constructor() {
        _disableInitializers();
    }

    function initialize(bytes calldata initdata) external initializer {
        (
            _hatsData.hats,
            _hatsData.characterHatEligibilityModule,
            _hatsData.playerHatEligibilityModule,
            _hatsData.adminHatId,
            _hatsData.dungeonMasterHatId,
            _hatsData.playerHatId,
            _hatsData.characterHatId
        ) = abi.decode(initdata, (address, address, address, uint256, uint256, uint256, uint256));
        __Ownable_init();
    }

    function updateHatsAddress(address newHatsAddress) external onlyOwner {
        _hatsData.hats = newHatsAddress;
        emit HatsAddressUpdated(newHatsAddress);
    }

    function updateCharacterHatModuleAddress(address newCharacterHatAddress) external onlyOwner {
        _hatsData.characterHatEligibilityModule = newCharacterHatAddress;
        emit CharacterHatEligibilityModuleAddressUpdated(newCharacterHatAddress);
    }

    function updatePlayerHatModuleAddress(address newPlayerAddress) external onlyOwner {
        _hatsData.playerHatEligibilityModule = newPlayerAddress;
        emit PlayerHatEligibilityModuleAddressUpdated(newPlayerAddress);
    }

    function updateAdminHatId(uint256 newAdminHatId) external onlyOwner {
        _hatsData.adminHatId = newAdminHatId;
        emit AdminHatIdUpdated(newAdminHatId);
    }

    function updateDungeonMasterHatId(uint256 newDungeonMasterHatId) external onlyOwner {
        _hatsData.dungeonMasterHatId = newDungeonMasterHatId;
        emit DungeonMasterHatIdUpdated(newDungeonMasterHatId);
    }

    function updatePlayerHatId(uint256 newPlayerHatId) external onlyOwner {
        _hatsData.playerHatId = newPlayerHatId;
        emit PlayerHatIdUpdated(newPlayerHatId);
    }

    function updateCharacterHatId(uint256 newCharacterHatId) external onlyOwner {
        _hatsData.characterHatId = newCharacterHatId;
        emit CharacterHatIdUpdated(newCharacterHatId);
    }

    function mintPlayerHat(address wearer) external returns (bool) {
        if (_hatsData.playerHatId == uint256(0)) {
            revert Errors.VariableNotSet();
        }
        (bool eligible,) = checkPlayerHatEligibility(wearer);
        if (!eligible) {
            revert Errors.PlayerError();
        }
        // look for emitted event from hats contract
        return IHats(_hatsData.hats).mintHat(_hatsData.playerHatId, wearer);
    }

    function mintCharacterHat(address wearer) external returns (bool) {
        if (_hatsData.characterHatId == uint256(0)) {
            revert Errors.VariableNotSet();
        }
        (bool eligible,) = checkCharacterHatEligibility(wearer);
        if (!eligible) {
            revert Errors.CharacterError();
        }
        // look for emitted event from hats contract
        return IHats(_hatsData.hats).mintHat(_hatsData.characterHatId, wearer);
    }

    function checkCharacterHatEligibility(address account) public view returns (bool eligible, bool standing) {
        return
            IHatsEligibility(_hatsData.characterHatEligibilityModule).getWearerStatus(account, _hatsData.characterHatId);
    }

    function checkPlayerHatEligibility(address account) public view returns (bool eligible, bool standing) {
        return IHatsEligibility(_hatsData.playerHatEligibilityModule).getWearerStatus(account, _hatsData.playerHatId);
    }

    function isCharacter(address wearer) public view returns (bool) {
        if (_hatsData.characterHatId == uint256(0)) {
            revert Errors.VariableNotSet();
        }
        return IHats(_hatsData.hats).balanceOf(wearer, _hatsData.characterHatId) > 0;
    }

    function isPlayer(address wearer) public view returns (bool) {
        if (_hatsData.playerHatId == uint256(0)) {
            revert Errors.VariableNotSet();
        }
        return IHats(_hatsData.hats).balanceOf(wearer, _hatsData.playerHatId) > 0;
    }

    function isDungeonMaster(address wearer) public view returns (bool) {
        if (_hatsData.dungeonMasterHatId == uint256(0)) {
            revert Errors.VariableNotSet();
        }
        return IHats(_hatsData.hats).balanceOf(wearer, _hatsData.dungeonMasterHatId) > 0;
    }

    function _authorizeUpgrade(address newImplementation) internal virtual override onlyOwner {}
}
