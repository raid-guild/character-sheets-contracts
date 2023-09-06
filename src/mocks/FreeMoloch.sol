// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IMolochDAO.sol";

contract Moloch is IMolochDAO {
    mapping(address => Member) internal _members;

    constructor() {}

    function _addMember(address _newMember) internal {
        _members[_newMember] = Member(
          _newMember,
          100,
          1000,
          true,
          0,
          0
        );
    }

    function members(address member) public returns (Member memory) {
        Member storage m = _members[member];
        if (m.exists) {
          return m;
        }
        _addMember(member);
        return _members[member];
    }
}
