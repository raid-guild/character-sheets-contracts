// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// import { console2 } from "forge-std/Test.sol"; // remove before deploy
import {HatsEligibilityModule, HatsModule} from "hats-module/HatsEligibilityModule.sol";
import {IERC1155} from "@openzeppelin-contracts/contracts/token/ERC1155/IERC1155.sol";
import {ICharacterSheets} from "../../interfaces/ICharacterSheets.sol";

/**
 * @title ElderEligibility
 * @author MrDeadCe11
 * @notice A Hats Protocol eligibility module that checks if a player owns a character sheet with desired number
 * of class Levels of any particular class tokenId
 */

contract ElderEligibility is HatsEligibilityModule {
    /*//////////////////////////////////////////////////////////////
                          PUBLIC CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /**
     * See: https://github.com/Hats-Protocol/hats-module/blob/main/src/HatsModule.sol
     * -----------------------------------------------------------------+
     * CLONE IMMUTABLE "STORAGE"                                        |
     * -----------------------------------------------------------------|
     * Offset             | Constant        | Type    | Length          |
     * -----------------------------------------------------------------|
     * 0                  | IMPLEMENTATION  | address | 20              |
     * 20                 | HATS            | address | 20              |
     * 40                 | hatId           | uint256 | 32              |
     * 72                 | CLASSES_ADDRESS | address | 20              |
     * 92                 | SHEETS_ADDRESS  | address | 20              |
     * 112                | ARRAY_LENGTH    | uint256 | 32              |
     * 144                | TOKEN_IDS       | uint256 | ARRAY_LENGTH*32 |
     * 144+(ARRAY_LENGTH) | MIN_BALANCES    | uint256 | ARRAY_LENGTH*32 |
     * -----------------------------------------------------------------+
     */

    /// The address of the ERC1155 contract used to check eligibility

    function CLASSES_ADDRESS() public pure returns (address) {
        return _getArgAddress(72);
    }

    function SHEETS_ADDRESS() public pure returns (address) {
        return _getArgAddress(92);
    }
    /// The length of the TOKEN_IDS & MIN_BALANCES arrays - these MUST be equal.

    function ARRAY_LENGTH() public pure returns (uint256) {
        return _getArgUint256(112);
    }

    /// The ERC1155token IDs that allow eligibility.
    /// @dev NOTE: Wearer must satisfy only one token ID criteria for eligiblity.
    /// @dev NOTE: the TOKEN_IDS length must match the MIN_BALANCES length
    function TOKEN_IDS() public pure returns (uint256[] memory) {
        return _getArgUint256Array(144, ARRAY_LENGTH());
    }

    /// The minimum balances required (for token ID in the corresponding index) for eligibility.
    /// @dev NOTE: Wearer must satisfy only one token ID criteria for eligiblity
    /// @dev NOTE: the TOKEN_IDS length must match the MIN_BALANCES length
    function MIN_BALANCES() public pure returns (uint256[] memory) {
        return _getArgUint256Array(144 + ARRAY_LENGTH() * 32, ARRAY_LENGTH());
    }

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Deploy the ERC1155Eligibility implementation contract and set its version
     * @dev This is only used to deploy the implementation contract, and should not be used to deploy clones
     */
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
        uint256 len = ARRAY_LENGTH();
        IERC1155 token = IERC1155(CLASSES_ADDRESS());

        uint256 characterId = ICharacterSheets(SHEETS_ADDRESS()).getCharacterIdByPlayerAddress(_wearer);
        address character =
            ICharacterSheets(SHEETS_ADDRESS()).getCharacterSheetByCharacterId(characterId).accountAddress;

        uint256[] memory tokenIds = TOKEN_IDS();
        uint256[] memory minBalances = MIN_BALANCES();

        for (uint256 i = 0; i < len;) {
            eligible = token.balanceOf(character, tokenIds[i]) >= minBalances[i];
            if (eligible) break;
            unchecked {
                ++i;
            }
        }
        standing = true;
    }
}
