// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC165} from "openzeppelin-contracts/utils/introspection/ERC165.sol";
import {OwnableUpgradeable} from "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";

import {UUPSUpgradeable} from "openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Initializable} from "openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";

import {IMolochDAO} from "../interfaces/IMolochDAO.sol";
import {ICharacterEligibilityAdaptor} from "../interfaces/ICharacterEligibilityAdaptor.sol";
import {Errors} from "../lib/Errors.sol";

/**
 * @notice this contract is to check and make sure that an address is eligible to roll a character sheet
 */
contract CharacterEligibilityAdaptor is
    ICharacterEligibilityAdaptor,
    ERC165,
    Initializable,
    OwnableUpgradeable,
    UUPSUpgradeable
{
    //(this.isEligible.selector ^ this.supportsInterface.selector);
    bytes4 public constant INTERFACE_ID = 0x671ccc5a;

    address public dao;

    event DaoUpdated(address newDaoAddress);

    constructor() {
        _disableInitializers();
    }

    function initialize(address _owner, address _dao) external initializer {
        dao = _dao;
        __Ownable_init(_owner);
    }

    function updateDaoAddress(address newDao) external onlyOwner {
        dao = newDao;
        emit DaoUpdated(newDao);
    }

    function isEligible(address account) public view returns (bool) {
        if (dao == address(0)) {
            revert Errors.NotInitialized();
        }

        IMolochDAO.Member memory newMember = IMolochDAO(dao).members(account);
        return (newMember.shares >= 100 && newMember.jailed == 0);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC165, ICharacterEligibilityAdaptor)
        returns (bool)
    {
        return interfaceId == 0x01ffc9a7 || interfaceId == INTERFACE_ID || super.supportsInterface(interfaceId);
    }

    //solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
