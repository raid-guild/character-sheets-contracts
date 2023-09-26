// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Initializable} from "openzeppelin-contracts/proxy/utils/Initializable.sol";
import {MerkleProof} from "openzeppelin-contracts/utils/cryptography/MerkleProof.sol";
import {ERC20Upgradeable} from "openzeppelin-contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {UUPSUpgradeable} from "openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {ICharacterSheets} from "../interfaces/ICharacterSheets.sol";
import {ClassesImplementation} from "./ClassesImplementation.sol";
import {Item, Class, CharacterSheet} from "../lib/Structs.sol";
import {Errors} from "../lib/Errors.sol";

/**
 * @title Experience and Items
 * @author MrDeadCe11
 * @notice this is an ERC20 that is designed to intereact with the items, character sheets, and classes contracts to provide a measurable amount of character advancment
 */
contract ExperienceImplementation is ERC20Upgradeable, UUPSUpgradeable {
    bytes32 public constant DUNGEON_MASTER = keccak256("DUNGEON_MASTER");
    bytes32 public constant CHARACTER = keccak256("CHARACTER");

    bytes32 public claimMerkleRoot;

    /// @dev the interface to the characterSheets erc721 implementation that this is tied to
    address public characterSheets;
    address public itemsContract;
    address public classesContract;

    modifier onlyDungeonMaster() {
        if (!ICharacterSheets(characterSheets).hasRole(DUNGEON_MASTER, msg.sender)) {
            revert Errors.DungeonMasterOnly();
        }
        _;
    }

    modifier onlyCharacter() {
        if (!ICharacterSheets(characterSheets).hasRole(CHARACTER, msg.sender)) {
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
        __ERC20_init_unchained("EXP", "Experience");
        __UUPSUpgradeable_init();
        (characterSheets, classesContract) = abi.decode(initializationData, (address, address));
    }

    /// @notice Called by dungeon master to give experience to a character
    /// @param to the address of the character that will receive the exp
    function dropExp(address to, uint256 amount) public onlyDungeonMaster {
        if (characterSheets == address(0)) {
            revert Errors.VariableNotSet();
        }
        if (!ICharacterSheets(characterSheets).hasRole(CHARACTER, to)) {
            revert Errors.CharacterError();
        }
        _mint(to, amount);
    }

    function giveExp(address to, uint256 amount) public onlyContract {
        if (characterSheets == address(0) || classesContract == address(0)) {
            revert Errors.VariableNotSet();
        }
        if (!ICharacterSheets(characterSheets).hasRole(CHARACTER, to)) {
            revert Errors.CharacterError();
        }
        _mint(to, amount);
    }

    function updateClaimMerkleRoot(bytes32 newMerkleRoot) public onlyDungeonMaster {}

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

    function _authorizeUpgrade(address newImplementation) internal override onlyDungeonMaster {}
}
