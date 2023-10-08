// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {ERC20Upgradeable} from "openzeppelin-contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {UUPSUpgradeable} from "openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {Errors} from "../lib/Errors.sol";
import {IExperience} from "../interfaces/IExperience.sol";
import {IHatsAdaptor} from "../interfaces/IHatsAdaptor.sol";

/**
 * @title Experience and Items
 * @author MrDeadCe11 && dan13ram
 * @notice this is an ERC20 that is designed to intereact with the items, character sheets, and classes contracts to provide a measurable amount of character advancment
 */
contract ExperienceImplementation is IExperience, ERC20Upgradeable, UUPSUpgradeable {
    bytes32 public constant DUNGEON_MASTER = keccak256("DUNGEON_MASTER");
    bytes32 public constant CHARACTER = keccak256("CHARACTER");

    /// @dev the interface to the characterSheets erc721 implementation that this is tied to
    address public characterSheets;
    address public itemsContract;
    address public classesContract;
    address public hatsAdaptor;

    modifier onlyDungeonMaster() {
        if (!IHatsAdaptor(hatsAdaptor).isDungeonMaster(msg.sender)) {
            revert Errors.DungeonMasterOnly();
        }
        _;
    }

    modifier onlyCharacter() {
        if (!IHatsAdaptor(hatsAdaptor).isCharacter(msg.sender)) {
            revert Errors.CharacterOnly();
        }
        _;
    }

    modifier onlyContract() {
        if (msg.sender != itemsContract && msg.sender != characterSheets && msg.sender != classesContract) {
            revert Errors.CallerNotApproved();
        }
        _;
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(bytes calldata initializationData) external initializer {
        __ERC20_init_unchained("Experience", "EXP");
        __UUPSUpgradeable_init();
        (characterSheets, classesContract, hatsAdaptor) = abi.decode(initializationData, (address, address, address));
    }

    /**
     * @notice Called by dungeon master to give experience to a character
     * @param to the address of the character that will receive the exp
     */
    function dropExp(address to, uint256 amount) public onlyDungeonMaster {
        if (characterSheets == address(0)) {
            revert Errors.VariableNotSet();
        }
        if (!IHatsAdaptor(hatsAdaptor).isCharacter(to)) {
            revert Errors.CharacterError();
        }
        _mint(to, amount);
    }

    function giveExp(address to, uint256 amount) public onlyContract {
        if (characterSheets == address(0) || classesContract == address(0)) {
            revert Errors.VariableNotSet();
        }
        if (!IHatsAdaptor(hatsAdaptor).isCharacter(to)) {
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
    //Experience is non transferable

    //solhint-disable-next-line no-unused-vars
    function transferFrom(address, address, uint256) public pure override returns (bool) {
        revert Errors.TransferError();
    }

    //solhint-disable-next-line no-unused-vars
    function transfer(address, uint256) public pure override returns (bool) {
        revert Errors.TransferError();
    }

    //solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address newImplementation) internal override onlyDungeonMaster {}
}
