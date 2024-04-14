// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// import { console2 } from "forge-std/Test.sol"; // remove before deploy
import {HatsEligibilityModule, HatsModule, IHatsEligibility} from "hats-module/HatsEligibilityModule.sol";

/*//////////////////////////////////////////////////////////////
                            CUSTOM ERRORS
//////////////////////////////////////////////////////////////*/

/// @dev Thrown when the caller does not wear the `OWNER_HAT`
error AllowlistEligibility_NotOwner();
/// @dev Thrown when the caller does not wear the `ARBITRATOR_HAT`
error AllowlistEligibility_NotArbitrator();
/// @dev Thrown when array args are not the same length
error AllowlistEligibility_ArrayLengthMismatch();
/// @dev Thrown if attempting to burn a hat that an account is not wearing
error AllowlistEligibility_NotWearer();

/**
 * @title AllowlistEligibility
 * @author spengrah
 * @author Haberdasher Labs
 * @notice A Hats Protocol eligibility module that allows the owner to add and remove accounts from an eligibility
 *         allowlist for a given hat.
 * @dev This contract inherits from HatsEligibilityModule and is designed to deployed as a clone via HatsModuleFactory.
 *      It must be set as the eligibility for {hatId} in order to be used.
 */
contract AllowlistEligibility is HatsEligibilityModule {
    /*//////////////////////////////////////////////////////////////
                            DATA MODELS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Eligibility and standing data for an account
     * @param eligible Whether the account is eligible to wear the hat. Defaults to not eligible.
     * @param badStanding Whether the account is in bad standing for the hat. Defaults to good standing.
     */
    struct EligibilityData {
        bool eligible;
        bool badStanding;
    }

    /*//////////////////////////////////////////////////////////////
                              EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when an account is added to the allowlist
    event AccountAdded(address account);
    /// @notice Emitted when multiple accounts are added to the allowlist
    event AccountsAdded(address[] accounts);
    /// @notice Emitted when an account is removed from the allowlist
    event AccountRemoved(address account);
    /// @notice Emitted when multiple accounts are removed from the allowlist
    event AccountsRemoved(address[] accounts);
    /// @notice Emitted when an account's standing is changed
    event AccountStandingChanged(address account, bool standing);
    /// @notice Emitted when multiple accounts' standing are changed
    event AccountsStandingChanged(address[] accounts, bool[] standing);

    /*//////////////////////////////////////////////////////////////
                            CONSTANTS 
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
     * ----------------------------------------------------------------------+
     * CLONE IMMUTABLE "STORAGE"                                             |
     * ----------------------------------------------------------------------|
     * Offset  | Constant          | Type    | Length  | Source              |
     * ----------------------------------------------------------------------|
     * 0       | IMPLEMENTATION    | address | 20      | HatsModule          |
     * 20      | HATS              | address | 20      | HatsModule          |
     * 40      | hatId             | uint256 | 32      | HatsModule          |
     * 72      | OWNER_HAT         | uint256 | 32      | this                |
     * 104     | ARBITRATOR_HAT    | uint256 | 32      | this                |
     * ----------------------------------------------------------------------+
     */

    /// @notice The hat ID for the owner hat. The wearer(s) of this hat are authorized to add and remove accounts from the
    /// allowlist
    // solhint-disable-next-line func-name-mixedcase
    function OWNER_HAT() public pure returns (uint256) {
        return _getArgUint256(72);
    }

    /// @notice The hat ID for the arbitrator hat. The wearer(s) of this hat are authorized to set the standing for
    /// accounts.
    // solhint-disable-next-line func-name-mixedcase
    function ARBITRATOR_HAT() public pure returns (uint256) {
        return _getArgUint256(104);
    }

    /*//////////////////////////////////////////////////////////////
                            MUTABLE STATE
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice The eligibility data for each account
     * @custom:param account The account to get eligibility data for
     * @custom:return eligibility The eligibility data for the account
     */
    // solhint-disable-next-line ordering
    mapping(address account => EligibilityData eligibility) public allowlist;

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Deploy the implementation contract and set its version
    /// @dev This is only used to deploy the implementation contract, and should not be used to deploy clones
    constructor(string memory _version) HatsModule(_version) {}

    /*//////////////////////////////////////////////////////////////
                            INITIALIZER
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc HatsModule
    function _setUp(bytes calldata _initData) internal override {
        // if there are no initial accounts to add, only initialize the clone instance
        if (_initData.length == 0) return;

        // otherwise, decode init data to look for initial accounts to add
        address[] memory _accounts = abi.decode(_initData, (address[]));
        // add initial accounts to allowlist
        _addAccountsMemory(_accounts);
    }

    /*//////////////////////////////////////////////////////////////
                      HATS ELIGIBILITY FUNCTION
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IHatsEligibility
    function getWearerStatus(address _wearer, uint256 /* _hatId */ )
        public
        view
        override
        returns (bool _eligible, bool _standing)
    {
        // load a pointer to the eligibility data in storage
        EligibilityData storage eligibility = allowlist[_wearer];

        // wearer is always ineligible if in bad standing
        if (eligibility.badStanding) return (false, false);

        _standing = true;
        _eligible = eligibility.eligible;
    }

    /*//////////////////////////////////////////////////////////////
                          ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Add an account to the allowlist
     * @dev Only callable by a wearer of the OWNER_HAT
     *      Does not revert if account is already added; overwrites existing eligibility data for the account
     * @param _account The account to add
     */
    function addAccount(address _account) public onlyOwner {
        allowlist[_account].eligible = true;

        emit AccountAdded(_account);
    }

    /**
     * @notice Add multiple accounts to the allowlist
     * @dev Only callable by a wearer of the OWNER_HAT
     *      Does not revert if an account is already added; overwrites existing eligibility data for the account
     * @param _accounts The array of accounts to add
     */
    function addAccounts(address[] calldata _accounts) public onlyOwner {
        for (uint256 i; i < _accounts.length;) {
            allowlist[_accounts[i]].eligible = true;
            unchecked {
                ++i;
            }
        }

        emit AccountsAdded(_accounts);
    }

    /**
     * @notice Remove an account from the allowlist
     * @dev Only callable by a wearer of the OWNER_HAT
     *      Does not revert if account is not yet added
     *      Revokes the account's hat if they are wearing it, but no burn event will be emitted
     * @param _account The account to remove
     */
    function removeAccount(address _account) public onlyOwner {
        allowlist[_account].eligible = false;

        emit AccountRemoved(_account);
    }

    /**
     * @notice Remove an account from the allowlist and revoke their hat
     * @dev Only callable by a wearer of the OWNER_HAT
     *      Will revert if the account is not wearing the hat
     *      Reverts if the account is not wearing the hat, but other does not revert if account is not yet added
     * @param _account The account to remove
     */
    function removeAccountAndBurnHat(address _account) public onlyOwner {
        if (!HATS().isWearerOfHat(_account, hatId())) revert AllowlistEligibility_NotWearer();

        EligibilityData storage eligibility = allowlist[_account];

        // remove the account from the allowlist
        eligibility.eligible = false;

        emit AccountRemoved(_account);

        // burn the hat by setting their eligibility to with the account's current standing
        HATS().setHatWearerStatus(hatId(), _account, false, !eligibility.badStanding);

        /**
         * @dev Hats.sol will emit the following events:
         *   1. ERC1155.TransferSingle (burn)
         *   2. Hats.WearerStandingChanged (if `eligibility.badStanding` differs from `Hats.badStandings(_account)`)
         */
    }

    /**
     * @notice Remove multiple accounts from the allowlist
     * @dev Only callable by a wearer of the OWNER_HAT
     *      Does not revert if an account is not yet added
     * @param _accounts The array of accounts to remove
     */
    function removeAccounts(address[] calldata _accounts) public onlyOwner {
        for (uint256 i; i < _accounts.length;) {
            allowlist[_accounts[i]].eligible = false;
            unchecked {
                ++i;
            }
        }

        emit AccountsRemoved(_accounts);
    }

    /**
     * @notice Set the standing for an account
     * @dev Only callable by a wearer of the ARBITRATOR_HAT
     *      Does not revert if an account is not yet added
     * @param _account The account to set standing for
     * @param _standing The standing to set
     */
    function setStandingForAccount(address _account, bool _standing) public onlyArbitrator {
        allowlist[_account].badStanding = !_standing;

        emit AccountStandingChanged(_account, _standing);
    }

    /**
     * @notice Puts an account in bad standing and burns their hat
     * @dev Only callable by a wearer of the ARBITRATOR_HAT
     *      Reverts if the account is not wearing the hat, but otherwise does not revert if an account is not yet added
     * @param _account The account to set standing for
     */
    function setBadStandingAndBurnHat(address _account) public onlyArbitrator {
        if (!HATS().isWearerOfHat(_account, hatId())) revert AllowlistEligibility_NotWearer();

        // set to bad standing in this contract
        allowlist[_account].badStanding = true;

        emit AccountStandingChanged(_account, false);

        // burn the account's hat by setting their eligibility and standing to false
        HATS().setHatWearerStatus(hatId(), _account, false, false);

        /**
         * @dev Hats.sol will emit the following events:
         *   1. ERC1155.TransferSingle (burn)
         *   2. Hats.WearerStandingChanged (if `Hats.badStandings(_account)==true`)
         */
    }

    /**
     * @notice Set the standing for multiple accounts
     * @dev Only callable by a wearer of the ARBITRATOR_HAT
     *      Does not revert if an account is not yet added
     * @param _accounts The array of accounts to set standing for
     * @param _standing The array of standings to set, indexed to the accounts array
     */
    function setStandingForAccounts(address[] calldata _accounts, bool[] calldata _standing) public onlyArbitrator {
        // arrays must be the same length
        if (_accounts.length != _standing.length) revert AllowlistEligibility_ArrayLengthMismatch();

        for (uint256 i; i < _accounts.length;) {
            allowlist[_accounts[i]].badStanding = !_standing[i];
            unchecked {
                ++i;
            }
        }

        emit AccountsStandingChanged(_accounts, _standing);
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Add multiple accounts to the allowlist, using memory instead of calldata for compatibility with {setUp}
     *   Note: overwrites existing eligibility data for the accounts
     * @param _accounts The array of accounts to add
     */
    function _addAccountsMemory(address[] memory _accounts) internal {
        for (uint256 i; i < _accounts.length;) {
            allowlist[_accounts[i]].eligible = true;
            unchecked {
                ++i;
            }
        }

        emit AccountsAdded(_accounts);
    }

    /*//////////////////////////////////////////////////////////////
                            MODIFERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Reverts if the caller is not wearing the OWNER_HAT.
    modifier onlyOwner() {
        if (!HATS().isWearerOfHat(msg.sender, OWNER_HAT())) revert AllowlistEligibility_NotOwner();
        _;
    }

    /// @notice Reverts if the caller is not wearing the ARBITRATOR_HAT.
    modifier onlyArbitrator() {
        if (!HATS().isWearerOfHat(msg.sender, ARBITRATOR_HAT())) revert AllowlistEligibility_NotArbitrator();
        _;
    }
}
