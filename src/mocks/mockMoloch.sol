// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IMolochDAO.sol";

contract Moloch {

    struct Member {
        address delegateKey; // the key responsible for submitting proposals and voting - defaults to member address unless updated
        uint256 shares; // the # of voting shares assigned to this member
        uint256 loot; // the loot amount available to this member (combined with shares on ragequit)
        bool exists; // always true once a member has been created
        uint256 highestIndexYesVote; // highest proposal index # on which the member voted YES
        uint256 jailed; // set to proposalIndex of a passing guild kick proposal for this member, prevents voting on and sponsoring proposals
    }

    mapping(address => Member) public members;

    constructor() {}

    function addMember(address _newMember) public {
        Member memory newMember;
        newMember.delegateKey = _newMember;
        newMember.shares = 100;
        newMember.loot = 1000;
        newMember.exists = true;
        members[_newMember] = newMember;
    }
}
