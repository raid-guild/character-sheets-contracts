// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
//solhint-disable
// import {console2} from "forge-std/Test.sol"; // remove before deploy

import {HatsEligibilityModule, HatsModule} from "hats-module/HatsEligibilityModule.sol";
import {IERC1155} from "@openzeppelin-contracts/contracts/token/ERC1155/IERC1155.sol";
import {ICharacterSheets} from "../../interfaces/ICharacterSheets.sol";

/**
 * @title ElderEligibility
 * @author MrDeadCe11
 * @notice A Hats Protocol eligibility module that checks if a player owns a character sheet with desired number
 * of class Levels of any particular class tokenId
 */

contract CharacterSheetsLevelEligibilityModule is HatsEligibilityModule {
    event ElderEligibilityDeployed(address);
    event ClassesAdded(uint256[], uint256[]);

    /// @notice Thrown when a non-admin tries to call an admin restricted function.
    error ElderEligibility_NotHatAdmin();
    /// @notice Thrown when a class addition is attempted on an immutable hat.
    error ElderEligibility_HatImmutable();
    /// @notice Thrown if the init data arrays are mismatched lengths
    error LengthMismatch();
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
     * -----------------------------------------------------------------+
     */

    /// The ERC1155token IDs that allow eligibility.
    /// @dev NOTE: Wearer must satisfy only one token ID criteria for eligiblity.
    /// @dev NOTE: the TOKEN_IDS length must match the MIN_BALANCES length
    uint256[] public classIds;

    /// The minimum balances required (for token ID in the corresponding index) for eligibility.
    /// @dev NOTE: Wearer must satisfy only one token ID criteria for eligiblity
    /// @dev NOTE: the TOKEN_IDS length must match the MIN_BALANCES length
    uint256[] public minLevels;

    function _setUp(bytes calldata _initData) internal override {
        // decode the _initData bytes and set the addresses as eligible
        (uint256[] memory _classIds, uint256[] memory _minLevels) = abi.decode(_initData, (uint256[], uint256[]));
        uint256 len = _classIds.length;

        if (len != _minLevels.length) {
            revert LengthMismatch();
        }

        for (uint256 i = 0; i < len; i++) {
            classIds.push(_classIds[i]);
            minLevels.push(_minLevels[i]);
        }

        // log the deployment & setup
        emit ElderEligibilityDeployed(address(this));
    }

    /// adds a class and minimum level to the classes and minLevels arrays
    function addClasses(uint256[] calldata _classIds, uint256[] calldata _minLevels)
        external
        onlyHatAdmin
        hatIsMutable
    {
        uint256 len = _classIds.length;

        if (len != _minLevels.length) {
            revert LengthMismatch();
        }

        for (uint256 i = 0; i < len;) {
            classIds.push(_classIds[i]);
            minLevels.push(_minLevels[i]);

            unchecked {
                i++;
            }
        }

        emit ClassesAdded(_classIds, _minLevels);
    }

    /// The address of the ERC1155 contract used to check eligibility
    function CLASSES_ADDRESS() public pure returns (address) {
        return _getArgAddress(72);
    }

    function SHEETS_ADDRESS() public pure returns (address) {
        return _getArgAddress(92);
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
        uint256 len = minLevels.length;
        IERC1155 token = IERC1155(CLASSES_ADDRESS());

        uint256 characterId = ICharacterSheets(SHEETS_ADDRESS()).getCharacterIdByPlayerAddress(_wearer);
        address character =
            ICharacterSheets(SHEETS_ADDRESS()).getCharacterSheetByCharacterId(characterId).accountAddress;

        for (uint256 i = 0; i < len;) {
            eligible = token.balanceOf(character, classIds[i]) >= minLevels[i];
            if (eligible) break;
            unchecked {
                ++i;
            }
        }
        standing = true;
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Returns whether this instance of ERC721Eligibility's hatId is mutable
     */
    function _hatIsMutable() internal view returns (bool _isMutable) {
        (,,,,,,, _isMutable,) = HATS().viewHat(hatId());
    }

    /*//////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyHatAdmin() {
        if (!HATS().isAdminOfHat(msg.sender, hatId())) {
            revert ElderEligibility_NotHatAdmin();
        }
        _;
    }

    modifier hatIsMutable() {
        if (!_hatIsMutable()) revert ElderEligibility_HatImmutable();
        _;
    }
}
