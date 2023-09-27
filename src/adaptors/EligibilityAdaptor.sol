// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {ERC165} from "openzeppelin-contracts/utils/introspection/ERC165.sol";
import {OwnableUpgradeable} from "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";

import {UUPSUpgradeable} from "openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Initializable} from "openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";

import {IMolochDAO} from "../interfaces/IMolochDAO.sol";
import {Errors} from "../lib/Errors.sol";

contract EligibilityAdaptor is ERC165, Initializable, OwnableUpgradeable, UUPSUpgradeable {
    //(this.isEligible.selector ^ this.supportsInterface.selector);
    bytes4 public constant INTERFACE_ID = 0x671ccc5a;

    /// @dev the admin of the contract
    bytes32 public constant DUNGEON_MASTER = keccak256("DUNGEON_MASTER");

    address public dao;

    event DaoUpdated(address newDaoAddress);

    constructor() {
        _disableInitializers();
    }

    function initialize(bytes calldata data) external initializer {
        dao = abi.decode(data, (address));
        __Ownable_init();
    }

    function updateDaoAddress(address newDao) external onlyOwner {
        dao = newDao;
        emit DaoUpdated(newDao);
    }

    function isEligible(address account) public returns (bool) {
        if (dao == address(0)) {
            revert Errors.NotInitialized();
        }

        IMolochDAO.Member memory newMember = IMolochDAO(dao).members(account);
        return (newMember.shares >= 100 && newMember.jailed == 0);
    }

    function supportsInterface(bytes4 interfaceId) public pure override returns (bool) {
        return interfaceId == 0x01ffc9a7 || interfaceId == INTERFACE_ID;
    }

    //solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
