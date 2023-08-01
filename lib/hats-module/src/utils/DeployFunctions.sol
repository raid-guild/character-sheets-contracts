// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import { console2 } from "forge-std/Test.sol";
import { HatsModule, HatsModuleFactory, IHats } from "../HatsModuleFactory.sol";

function deployModuleFactory(IHats _hats, bytes32 _salt, string memory _version) returns (HatsModuleFactory _factory) {
  _factory = new HatsModuleFactory{ salt: _salt}(_hats, _version);
}

function deployModuleInstance(
  HatsModuleFactory _factory,
  address _implementation,
  uint256 _hatId,
  bytes memory _otherImmutableArgs,
  bytes memory _initData
) returns (address _instance) {
  _instance = _factory.createHatsModule(_implementation, _hatId, _otherImmutableArgs, _initData);
}
