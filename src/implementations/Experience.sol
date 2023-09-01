// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Initializable} from "openzeppelin/proxy/utils/Initializable.sol";
import {MerkleProof} from "openzeppelin/utils/cryptography/MerkleProof.sol";
import {ERC20} from "hats/lib/ERC20/ERC20.sol";
import {IERC721} from "openzeppelin/token/ERC721/IERC721.sol";

import {CharacterSheetsImplementation} from "./CharacterSheetsImplementation.sol";
import {ClassesImplementation} from "./ClassesImplementation.sol";
import {Item, Class, CharacterSheet} from "../lib/Structs.sol";

import {Errors} from "../lib/Errors.sol";

/**
 * @title Experience and Items
 * @author MrDeadCe11
 * @notice this is an ERC1155 that is designed to intereact with the characterSheets contract.
 * Each item and class is an 1155 token that can soulbound or not to the erc6551 wallet of each player nft
 * in the characterSheets contract.
 */
contract ExperienceAndItemsImplementation is ERC20 {
    bytes32 public constant DUNGEON_MASTER = keccak256("DUNGEON_MASTER");
    bytes32 public constant PLAYER = keccak256("PLAYER");
    bytes32 public constant CHARACTER = keccak256("CHARACTER");

    bytes32 public claimersMerkleRoot;

    /// @dev the interface to the characterSheets erc721 implementation that this is tied to
    CharacterSheetsImplementation public characterSheets;
    address experienceContract;

    modifier onlyDungeonMaster() {
        if (!characterSheets.hasRole(DUNGEON_MASTER, msg.sender)) {
            revert Errors.DungeonMasterOnly();
        }
        _;
    }

    modifier onlyPlayer() {
        if (!characterSheets.hasRole(PLAYER, msg.sender)) {
            revert Errors.PlayerOnly();
        }
        _;
    }

    modifier onlyCharacter() {
        if (!characterSheets.hasRole(CHARACTER, msg.sender)) {
            revert Errors.CharacterOnly();
        }
        _;
    }

    constructor() ERC20("EXP", "Experience") {
        _disableInitializers();
    }

    function initialize(bytes calldata initializationData) external initializer {}

    function dropExp(address to, uint256 amount) public onlyDungeonMaster {}

    function claimExp(uint256 amount) public onlyCharacter {}

    function updateCharacterSheetsImplementation(address newSheets) public onlyDungeonMaster {}

    function updateClaimMerkleRoot(bytes32 calldata newMerkleRoot) public onlyDungeonMaster {}

    function burnExp(address burnee, uint256 amount) public onlyExperienceContract {}
}
