// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

// import { console2 } from "forge-std/Test.sol"; // remove before deploy
import { HatsModule } from "./HatsModule.sol";
import { IHatsEligibility } from "hats-protocol/Interfaces/IHatsEligibility.sol";

abstract contract HatsEligibilityModule is HatsModule, IHatsEligibility {
  /**
   * @dev Contracts that inherit from HatsEligibilityModule must call the HatsModule constructor:
   * `HatsModule(_version)`.
   */

  /*//////////////////////////////////////////////////////////////
                      HATS ELIGIBILITY FUNCTION
  //////////////////////////////////////////////////////////////*/

  /// @inheritdoc IHatsEligibility
  function getWearerStatus(address _wearer, uint256 _hatId)
    public
    view
    virtual
    override
    returns (bool eligible, bool standing)
  { }
}
