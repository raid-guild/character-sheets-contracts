// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// import { console2 } from "forge-std/Test.sol"; // remove before deploy
import {HatsEligibilityModule, HatsModule} from "hats-module/HatsEligibilityModule.sol";
import {IERC721} from "openzeppelin-contracts/token/ERC721/IERC721.sol";

/**
 * @title player hat eligibility module
 * @author MrDeadCe11
 * @notice A Hats Protocol eligibility module.  Addresses must own a character sheet to be eligible to be a player.
 */
contract PlayerHatEligibilityModule is HatsModule, HatsEligibilityModule {
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
     * 72      | TOKEN_ADDRESS   | address | 20      |                     |
     * 92      | MIN_BALANCE     | uint256 | 32      |                     |
     * --------------------------------------------------------------------+
     */

    /// The address of the ERC721 contract used to check eligibility
    function ERC721_TOKEN_ADDRESS() public pure returns (address) {
        return _getArgAddress(72);
    }

    /// The minimum token balance required to be eligible
    function MIN_BALANCE() public pure returns (uint256) {
        return _getArgUint256(92);
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
        uint256 balance = IERC721(ERC721_TOKEN_ADDRESS()).balanceOf(_wearer);
        eligible = balance >= MIN_BALANCE();
        standing = true;
    }
}
