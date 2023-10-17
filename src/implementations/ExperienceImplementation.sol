// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20Upgradeable} from "openzeppelin-contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {UUPSUpgradeable} from "openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {Errors} from "../lib/Errors.sol";
import {IExperience} from "../interfaces/IExperience.sol";
import {IHatsAdaptor} from "../interfaces/IHatsAdaptor.sol";
import {IClonesAddressStorage} from "../interfaces/IClonesAddressStorage.sol";
// import "forge-std/console2.sol";

/**
 * @title Experience and Items
 * @author MrDeadCe11 && dan13ram
 * @notice this is an ERC20 that is designed to intereact with the items, character sheets, and classes contracts to provide a measurable amount of character advancment
 */
contract ExperienceImplementation is IExperience, ERC20Upgradeable, UUPSUpgradeable {
    /// @dev the interface to the characterSheets erc721 implementation that this is tied to
    IClonesAddressStorage public clones;

    modifier onlyDungeonMaster() {
        if (!IHatsAdaptor(clones.hatsAdaptorClone()).isDungeonMaster(msg.sender)) {
            revert Errors.DungeonMasterOnly();
        }
        _;
    }

    modifier onlyCharacter() {
        if (!IHatsAdaptor(clones.hatsAdaptorClone()).isCharacter(msg.sender)) {
            revert Errors.CharacterOnly();
        }
        _;
    }

    modifier onlyContract() {
        if (
            msg.sender != clones.itemsClone() && msg.sender != clones.characterSheetsClone()
                && msg.sender != clones.classesClone() && msg.sender != clones.itemsClone()
                && msg.sender != clones.itemsManagerClone()
        ) {
            revert Errors.CallerNotApproved();
        }
        _;
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(address clonesStorage) external initializer {
        __ERC20_init_unchained("Experience", "EXP");
        __UUPSUpgradeable_init();
        clones = IClonesAddressStorage(clonesStorage);
    }

    /**
     * @notice Called by dungeon master to give experience to a character
     * @param to the address of the character that will receive the exp
     */
    function dropExp(address to, uint256 amount) public onlyDungeonMaster {
        if (!IHatsAdaptor(clones.hatsAdaptorClone()).isCharacter(to)) {
            revert Errors.CharacterError();
        }
        _mint(to, amount);
    }

    function giveExp(address to, uint256 amount) public onlyContract {
        if (!IHatsAdaptor(clones.hatsAdaptorClone()).isCharacter(to)) {
            revert Errors.CharacterError();
        }
        _mint(to, amount);
    }

    function revokeExp(address account, uint256 amount) public onlyDungeonMaster {
        _burn(account, amount);
    }

    function burnExp(address account, uint256 amount) public onlyContract {
        _burn(account, amount);
    }

    // overrides
    //Experience is non transferable except by approved contracts

    //solhint-disable-next-line no-unused-vars
    function transferFrom(address from, address to, uint256 amount) public override onlyContract returns (bool) {
        super.transferFrom(from, to, amount);
        return true;
    }

    //solhint-disable-next-line no-unused-vars
    function transfer(address to, uint256 amount) public override onlyContract returns (bool) {
        super.transfer(to, amount);
        return true;
    }

    /**
     * @notice 0 decimals.  1 exp = 1 exp
     */

    function decimals() public pure override returns (uint8) {
        return 0;
    }

    //solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address newImplementation) internal override onlyDungeonMaster {}
}
