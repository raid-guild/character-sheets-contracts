// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
//solhint-disable

import {HatsEligibilityModule, HatsModule} from "hats-module/HatsEligibilityModule.sol";
import {IERC721} from "openzeppelin-contracts/token/ERC721/IERC721.sol";

import {ICharacterSheets} from "../../interfaces/ICharacterSheets.sol";
import {IERC6551Registry} from "../../interfaces/IERC6551Registry.sol";
import {Errors} from "../../lib/Errors.sol";

/**
 * @title character hat eligibility module
 * @author MrDeadCe11
 * @notice A Hats Protocol eligibility module that checks if the address of the wearer is the
 * correct address of the ERC6551 account implementation used in the character sheets contract.
 * if a player is removed, or renounces their sheet the character retains it's character hat.
 */
contract CharacterHatEligibilityModule is HatsModule, HatsEligibilityModule {
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
     * 40      | hatId           | uint256 | 32      |                     |
     * 72      | ERC6551REGISTRY | address | 20      |                     |
     * 92      | ACCOUNT_IMPLEMENTATION    | address | 20    |             |
     * 112     | CHARACTERSHEETS | address | 20    |             |
     * --------------------------------------------------------------------+
     */

    /// The address of the ERC721 contract used to check eligibility
    function ERC6551_REGISTRY() public pure returns (address) {
        return _getArgAddress(72);
    }

    /// The ERC6551 account implementation address
    function ACCOUNT_IMPLEMENTATION() public pure returns (address) {
        return _getArgAddress(92);
    }

    function CHARACTERSHEETS() public pure returns (address) {
        return _getArgAddress(112);
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
        uint256 characterId = ICharacterSheets(CHARACTERSHEETS()).getCharacterIdByAccountAddress(_wearer);
        address createdAddress = IERC6551Registry(ERC6551_REGISTRY()).account(
            ACCOUNT_IMPLEMENTATION(), block.chainid, CHARACTERSHEETS(), characterId, characterId
        );

        eligible = createdAddress == _wearer;
        standing = true;
    }
}
