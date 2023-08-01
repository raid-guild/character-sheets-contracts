# HatsModule

HatsModule is a base contract for creating modules and hatter contracts for [Hats Protocol](https://github.com/hats-protocol/hats-protocol). Such modules are designed to be deployed as minimal proxy clones (with immutable args) via the included HatsModuleFactory.

## HatsModule Details

A HatsModule is a simple contract designed to be inherited by contracts that implement specific functionality for Hats Protocol. It exposes several functions for reading immutable storage related to the module:

- `IMPLEMENTATION()`: The address of the implementation contract of which the module is a clone.
- `HATS()`: The address of the Hats Protocol contract.
- `hatId()`: The ID of the hat that the module is associated with. This could be 0 if the module is not associated with any hat.
- `version()`: The version of the module.

### HatsEligibilityModule

An abstract contract that inherits from HatsModule and implements the [IHatsEligibility](https://github.com/Hats-Protocol/hats-protocol/blob/main/src/Interfaces/IHatsEligibility.sol) interface. This contract is designed to be inherited by contracts that implement eligibility logic for Hats Protocol.

### HatsToggleModule

An abstract contract that inherits from HatsModule and implements the [IHatsToggle](https://github.com/Hats-Protocol/hats-protocol/blob/main/src/Interfaces/IHatsToggle.sol) interface. This contract is designed to be inherited by contracts that implement toggle logic for Hats Protocol.

## HatsModuleFactory

The HatsModuleFactory is a contract that deploys minimal proxy clones of HatsModules. It deploys clones of an implementation contract with customizable immutable args, and initializes the clones with the `setUp` function of the implementation contract.
