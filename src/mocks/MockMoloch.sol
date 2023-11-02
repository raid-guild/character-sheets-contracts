// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IMolochDAOV2} from "../interfaces/IMolochDAOV2.sol";
import {IMolochDAOV3} from "../interfaces/IMolochDAOV3.sol";

contract Moloch is IMolochDAOV2, IMolochDAOV3 {
    mapping(address => Member) private _members;

    address public sharesToken;

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

    function setSharesToken(address newToken) public {
        sharesToken = newToken;
    }

    function jailMember(address member) public {
        _members[member].jailed = 100;
    }

    function unjailMember(address member) public {
        _members[member].jailed = 0;
    }
}
