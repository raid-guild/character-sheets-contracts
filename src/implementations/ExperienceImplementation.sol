// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20Upgradeable} from "openzeppelin-contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {UUPSUpgradeable} from "openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {Errors} from "../lib/Errors.sol";
import {IHatsAdaptor} from "../interfaces/IHatsAdaptor.sol";
import {IClonesAddressStorage} from "../interfaces/IClonesAddressStorage.sol";
// import "forge-std/console2.sol";

/**
 * @title Experience and Items
 * @author MrDeadCe11 && dan13ram
 * @notice this is an ERC20 that is designed to intereact with the items, character sheets, and classes contracts to provide a measurable amount of character advancment.
 * @dev the digits of this contracts are set to 0.  therefore 1exp = 1exp and is not divisibile into smaller units of exp.
 */
contract ExperienceImplementation is ERC20Upgradeable, UUPSUpgradeable {
    /// @dev the interface to the characterSheets erc721 implementation that this is tied to
    IClonesAddressStorage public clones;

    modifier onlyAdmin() {
        if (!IHatsAdaptor(clones.hatsAdaptor()).isAdmin(msg.sender)) {
            revert Errors.AdminOnly();
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
     * @notice Called by game master or an authorized contract to give experience to a character
     * @param to the address of the character that will receive the exp
     */
    function dropExp(address to, uint256 amount) public {
        if (!_isAuthorized(msg.sender)) {
            revert Errors.CallerNotApproved();
        }
        if (!IHatsAdaptor(clones.hatsAdaptor()).isCharacter(to)) {
            revert Errors.CharacterError();
        }
        _mint(to, amount);
    }

    function burnExp(address account, uint256 amount) public {
        if (!_isAuthorized(msg.sender)) {
            revert Errors.CallerNotApproved();
        }
        _burn(account, amount);
    }

    // overrides
    // Experience is non transferable except by approved contracts

    //solhint-disable-next-line no-unused-vars
    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        if (!_isAuthorized(msg.sender)) {
            revert Errors.CallerNotApproved();
        }
        super.transferFrom(from, to, amount);
        return true;
    }

    //solhint-disable-next-line no-unused-vars
    function transfer(address to, uint256 amount) public override returns (bool) {
        if (!_isAuthorized(msg.sender)) {
            revert Errors.CallerNotApproved();
        }
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
    function _authorizeUpgrade(address newImplementation) internal override onlyAdmin {}

    function _isAuthorized(address account) internal view returns (bool) {
        if (
            account != clones.items() && account != clones.characterSheets() && account != clones.classes()
                && account != clones.items() && account != clones.itemsManager()
                && !IHatsAdaptor(clones.hatsAdaptor()).isGameMaster(account)
        ) {
            return false;
        }
        return true;
    }
}
