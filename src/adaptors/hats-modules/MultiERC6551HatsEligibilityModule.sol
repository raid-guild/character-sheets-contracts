// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
//solhint-disable

import {HatsEligibilityModule, HatsModule} from "hats-module/HatsEligibilityModule.sol";
import {IERC721} from "openzeppelin-contracts/token/ERC721/IERC721.sol";

import {ICharacterSheets} from "../../interfaces/ICharacterSheets.sol";
import {IERC6551Registry} from "../../interfaces/IERC6551Registry.sol";
import {Errors} from "../../lib/Errors.sol";

/**
 * @title ERC6551 eligibility module
 * @author MrDeadCe11
 * @notice A Hats Protocol eligibility module that checks if an array of addresses is the correct address of an ERC6551 account according to the inputs
 */
contract MultiERC6551HatsEligibilityModule is HatsModule, HatsEligibilityModule {
    uint256 public totalValidGames;
    mapping(uint256 => address) ValidGames;

    /// @notice Thrown when a non-admin tries to call an admin restricted function.
    error MultiERC6551_NotHatAdmin();
    /// @notice Thrown when a class addition is attempted on an immutable hat.
    error MultiERC6551_HatImmutable();

    error foo();

    event MultiERC6551Deployed(address MultiERC6551Module);
    event NewGameAdded(address newGame);
    event GameRemoved(address removedGame, uint256 index);
    /*//////////////////////////////////////////////////////////////
                          PUBLIC CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /**
     * See: https://github.com/Hats-Protocol/hats-module/blob/main/src/HatsModule.sol
     * --------------------------------------------------------------------+
     * CLONE IMMUTABLE "STORAGE"                                           |
     * --------------------------------------------------------------------|
     * Offset  | Constant        | Type    | Length  |                     |
     * --------------------------------------------------------------------|
     * 0       | IMPLEMENTATION  | address | 20      |                     |
     * 20      | HATS            | address | 20      |                     |
     * 40      | hatId           | uint256 | 32      |
     * 72      | ADMINHATID      | uint256 | 32      |                    |
     * 104     | ERC6551REGISTRY | address | 20      |                     |
     * 124     | ACCOUNT_IMPLEMENTATION    | address | 20                  |
     * --------------------------------------------------------------------+
     */

    /// The address of the ERC721 contract used to check eligibility
    function ERC6551_REGISTRY() public pure returns (address) {
        return _getArgAddress(104);
    }

    /// The ERC6551 account implementation address
    function ACCOUNT_IMPLEMENTATION() public pure returns (address) {
        return _getArgAddress(124);
    }

    function ADMINHATID() public pure returns (uint256) {
        return _getArgUint256(72);
    }

    function addValidGame(address newGame) public onlyAdmin hatIsMutable {
        totalValidGames++;
        ValidGames[totalValidGames] = newGame;
        emit NewGameAdded(newGame);
    }

    function addValidGames(address[] calldata newGames) public onlyAdmin hatIsMutable {
        for (uint256 i; i < newGames.length; i++) {
            addValidGame(newGames[i]);
        }
    }

    function removeGame(uint256 gameIndex) public onlyAdmin hatIsMutable {
        address gameAddress = ValidGames[gameIndex];
        delete ValidGames[gameIndex];
        emit GameRemoved(gameAddress, gameIndex);
    }

    function _setUp(bytes calldata _initData) internal override {
        // decode the _initData bytes and set the addresses as eligible
        (address validGame) = abi.decode(_initData, (address));

        totalValidGames++;
        ValidGames[totalValidGames] = validGame;

        // log the deployment & setup
        emit MultiERC6551Deployed(address(this));
    }

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Deploy the ERC721Eligibility implementation contract and set its version
    /// @dev This is only used to deploy the implementation contract, and should not be used to deploy clones
    constructor(string memory _version) HatsModule(_version) {}

    /*//////////////////////////////////////////////////////////////
                        HATS ELIGIBILITY FUNCTION
    //////////////////////////////////////////////////////////////*/
    /**
     * @inheritdoc HatsEligibilityModule
     */
    function getWearerStatus(address _wearer, uint256 /*_hatId */ )
        public
        view
        override
        returns (bool eligible, bool standing)
    {
        for (uint256 i = 1; i <= totalValidGames;) {
            uint256 characterId = ICharacterSheets(ValidGames[i]).getCharacterIdByAccountAddress(_wearer);
            address createdAddress = IERC6551Registry(ERC6551_REGISTRY()).account(
                ACCOUNT_IMPLEMENTATION(), block.chainid, ValidGames[i], characterId, characterId
            );

            eligible = createdAddress == _wearer;
            standing = true;
            if (eligible) {
                break;
            }
            {
                i++;
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Returns whether this instance of MultiERC6551's hatId is mutable
     */
    function _hatIsMutable() internal view returns (bool _isMutable) {
        (,,,,,,, _isMutable,) = HATS().viewHat(hatId());
    }

    /*//////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyHatAdmin() {
        if (!HATS().isAdminOfHat(msg.sender, hatId())) {
            revert MultiERC6551_NotHatAdmin();
        }
        _;
    }

    modifier onlyAdmin() {
        if (!HATS().isWearerOfHat(msg.sender, ADMINHATID())) {
            revert MultiERC6551_NotHatAdmin();
        }
        _;
    }

    modifier hatIsMutable() {
        if (!_hatIsMutable()) revert MultiERC6551_HatImmutable();
        _;
    }
}
