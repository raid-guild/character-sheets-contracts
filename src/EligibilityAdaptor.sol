// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {ERC165} from "openzeppelin-contracts/utils/introspection/ERC165.sol";
import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";

import {IMolochDAO} from "./interfaces/IMolochDAO.sol";
import {IEligibilityAdaptor} from "./interfaces/IEligibilityAdaptor.sol";
import {ICharacterSheets} from "./interfaces/ICharacterSheets.sol";
import {Errors} from "./lib/Errors.sol";

contract EligibilityAdaptor is ERC165, Ownable {
    //(this.isEligible.selector ^ this.supportsInterface.selector);
    bytes4 public constant INTERFACE_ID = 0x671ccc5a;

    /// @dev the admin of the contract
    bytes32 public constant DUNGEON_MASTER = keccak256("DUNGEON_MASTER");

    address public dao;
    address public characterSheets;

    event DaoUpdated(address newDaoAddress);

    constructor() {}

    function updateDaoAddress(address newDao) external onlyOwner {
        dao = newDao;
        emit DaoUpdated(newDao);
    }

    function isEligible(address account) public returns (bool) {
        require(dao != address(0), "must set moloch dao address");

        IMolochDAO.Member memory newMember = IMolochDAO(dao).members(account);
        return (newMember.shares >= 100 && newMember.jailed == 0);
    }

    function supportsInterface(bytes4 interfaceId) public pure override returns (bool) {
        return interfaceId == 0x01ffc9a7 || interfaceId == INTERFACE_ID;
    }
}
