// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
pragma abicoder v2;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import {TestStructs} from "./TestStructs.sol";

contract Accounts is Test {
    TestStructs.Accounts public accounts;

    constructor() {
        accounts.admin = address(0xdeadce11);
        accounts.dungeonMaster = address(0xc0ffee);
        accounts.player1 = address(0xbeef);
        accounts.player2 = address(0xbabe);
        accounts.rando = address(777);
    }
}
