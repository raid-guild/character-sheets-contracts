// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
//solhint-disable

import {HatsEligibilityModule, HatsModule} from "hats-module/HatsEligibilityModule.sol";

/**
 * @title AddressEligibility
 * @author pumpedlunch
 * @notice A Hats Protocol eligibility module that allows admin's of a hat to whitelist eligible addresses for that hat
 * the admins of this contract will be the admins set by the admin contract.  This was to allow a more flexible set of dungeon masters
 * controlled by a more difficult to change set of admins.
 */

contract DungeonMasterHatEligibilityModule is HatsEligibilityModule {
    /*//////////////////////////////////////////////////////////////
                            CUSTOM ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when a non-admin tries to call an admin restricted function.
    error AddressEligibility_NotHatAdmin();
    /// @notice Thrown when a change to the eligible addresses is attempted on an immutable hat.
    error AddressEligibility_HatImmutable();

    /*//////////////////////////////////////////////////////////////
                              EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a AddressEligibility is deployed with `eligibleAddresses`
    event AddressEligibility_Deployed(address[] eligibleAddresses);
    /// @notice Emitted when an array of `addresses` are added as eligible
    event AddressEligibility_AddressesAdded(address[] addresses);
    /// @notice Emitted when an array of `addresses` are removed from eligibility
    event AddressEligibility_AddressesRemoved(address[] addresses);

    /*//////////////////////////////////////////////////////////////
                          PUBLIC CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /**
     * This contract is a clone with immutable args, which means that it is deployed with a set of
     * immutable storage variables (ie constants). Accessing these constants is cheaper than accessing
     * regular storage variables (such as those set on initialization of a typical EIP-1167 clone),
     * but requires a slightly different approach since they are read from calldata instead of storage.
     *
     * Below is a table of constants and their location.
     *
     * For more, see here: https://github.com/Saw-mon-and-Natalie/clones-with-immutable-args
     *
     * --------------------------------------------------------------------+
     * CLONE IMMUTABLE "STORAGE"                                           |
     * --------------------------------------------------------------------|
     * Offset  | Constant        | Type    | Length  |                     |
     * --------------------------------------------------------------------|
     * 0       | IMPLEMENTATION  | address | 20      |                     |
     * 20      | HATS            | address | 20      |                     |
     * 40      | hatId           | uint256 | 32      |                     |
     * --------------------------------------------------------------------+
     */

    /*//////////////////////////////////////////////////////////////
                               MUTABLE STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice addresses that are eligilbe for the Hat
    mapping(address => bool) public isEligible;

    /*//////////////////////////////////////////////////////////////
                                INITIALIZER
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc HatsModule
     */
    function _setUp(bytes calldata _initData) internal override {
        // decode the _initData bytes and set the addresses as eligible
        address[] memory _addresses = abi.decode(_initData, (address[]));
        uint256 len = _addresses.length;
        for (uint256 i = 0; i < len; i++) {
            isEligible[_addresses[i]] = true;
        }

        // log the deployment & setup
        emit AddressEligibility_Deployed(_addresses);
    }

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Deploy the AddressEligibility implementation contract and set its version
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
        eligible = isEligible[_wearer];
        standing = true;
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice makes addresses eligible
     * @param _addresses array of addresses to make eligible
     */
    function addEligibleAddresses(address[] calldata _addresses) external onlyHatAdmin hatIsMutable {
        uint256 len = _addresses.length;
        for (uint256 i = 0; i < len; i++) {
            isEligible[_addresses[i]] = true;
        }
        emit AddressEligibility_AddressesAdded(_addresses);
    }

    /**
     * @notice makes addresses ineligible
     * @param _addresses array of addresses to make ineligible
     */
    function removeEligibleAddresses(address[] calldata _addresses) external onlyHatAdmin hatIsMutable {
        uint256 len = _addresses.length;
        for (uint256 i = 0; i < len;) {
            isEligible[_addresses[i]] = false;

            unchecked {
                ++i;
            }
        }
        emit AddressEligibility_AddressesRemoved(_addresses);
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
            revert AddressEligibility_NotHatAdmin();
        }
        _;
    }

    modifier hatIsMutable() {
        if (!_hatIsMutable()) revert AddressEligibility_HatImmutable();
        _;
    }
}
