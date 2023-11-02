// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";

contract MockSharesToken is ERC20 {
    constructor() ERC20("MOCK SHARES", "MCK") {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}
