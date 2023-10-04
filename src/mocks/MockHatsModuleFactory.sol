// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// import { console2 } from "forge-std/Test.sol"; // remove before deploy
import {HatsModuleFactory} from "hats-module/HatsModuleFactory.sol";
import {LibClone} from "solady/utils/LibClone.sol";
import {IHats} from "hats-protocol/Interfaces/IHats.sol";

abstract contract MockHatsModuleFactory is HatsModuleFactory {}
