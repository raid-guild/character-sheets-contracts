// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IMolochDAO} from "../interfaces/IMolochDAO.sol";

contract Moloch is IMolochDAO {
    mapping(address => Member) public _members;

    function members(address memberAddress) external view override returns (Member memory member) {
        return _members[memberAddress];
    }

    function addMember(address _newMember) public {
        Member memory newMember;
        newMember.delegateKey = _newMember;
        newMember.shares = 100;
        newMember.loot = 1000;
        newMember.exists = true;
        _members[_newMember] = newMember;
    }

    function jailMember(address member) public {
        _members[member].jailed = 100;
    }
}
