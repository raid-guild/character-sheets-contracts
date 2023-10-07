// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {ERC165} from "openzeppelin-contracts/utils/introspection/ERC165.sol";
import {UUPSUpgradeable} from "openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import {IHats} from "hats-protocol/Interfaces/IHats.sol";
import {ERC1155HolderUpgradeable} from
    "openzeppelin-contracts-upgradeable/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";
import {IHatsEligibility} from "hats-protocol/Interfaces/IHatsEligibility.sol";
import {HatsModuleFactory} from "hats-module/HatsModuleFactory.sol";

import {Errors} from "../lib/Errors.sol";
import {HatsData} from "../lib/Structs.sol";

import "forge-std/console2.sol";

/**
 * @title Hats Adaptor
 * @author MrDeadCe11
 * @notice This is an adaptor that will automatically create the appropriate hat tree for the
 * character sheets contracts.  It also allows the minting of hats to players and characters
 * and checks if any address is wearing the player or character hat.
 */

contract HatsAdaptor is Initializable, OwnableUpgradeable, UUPSUpgradeable, ERC1155HolderUpgradeable {
    HatsData private _hatsData;

    IHats private _hats;

    /**
     * @notice these are the addresses of the eligibility modules after they are created by
     * the hats module factory during contract initialization.
     */
    address public adminHatEligibilityModule;
    address public dungeonMasterHatEligibilityModule;
    address public playerHatEligibilityModule;
    address public characterHatEligibilityModule;

    uint32 public constant MAX_SUPPLY = 200;

    string private _baseHatImgUri;

    event HatsAddressUpdated(address);
    event AdminHatEligibilityModuleAddressUpdated(address);
    event DungeonMasterHatEligibilityModuleAddressUpdated(address);
    event CharacterHatEligibilityModuleAddressUpdated(address);
    event PlayerHatEligibilityModuleAddressUpdated(address);
    event AdminHatIdUpdated(uint256);
    event DungeonMasterHatIdUpdated(uint256);
    event PlayerHatIdUpdated(uint256);
    event CharacterHatIdUpdated(uint256);

    constructor() {
        _disableInitializers();
    }

    /**
     * HATS ADDRESSES
     *        1.  address hats,
     *        2.  address hatsModuleFactory,
     *        3.  address adminHatEligibilityModule
     *        4.  address dungeonMasterEligibilityModuleImplementation
     *        5.  address playerHatEligibilityModuleImplementation
     *        6.  address characterHatEligibilityModuleImplementation
     *        7.  address[]  admins
     *        8.  address[] dungeon masters
     *        9.  address character sheets
     *        10.  address erc6551 registry
     *        11. address erc6551 account implementation
     */

    /**
     * HATS STRINGS
     *        1.  string _baseImgUri
     *        2.  string topHatDescription
     *        3.  string adminUri
     *        4.  string adminDescription
     *        5.  string dungeonMasterUri
     *        6.  string dungeonMasterDescription
     *        7.  string playerUri
     *        8.  string playerDescription
     *        9.  string characterUri
     *        10. string characterDescription
     */

    function initialize(address _owner, bytes calldata hatsAddresses, bytes calldata hatsStrings)
        external
        initializer
    {
        (
            _hatsData.hats,
            _hatsData.hatsModuleFactory,
            _hatsData.adminHatEligibilityModuleImplementation,
            _hatsData.dungeonMasterHatEligibilityModuleImplementation,
            _hatsData.playerHatEligibilityModuleImplementation,
            _hatsData.characterHatEligibilityModuleImplementation,
            ,
            ,
            ,
            ,
        ) = abi.decode(
            hatsAddresses,
            (address, address, address, address, address, address, address[], address[], address, address, address)
        );

        _hats = IHats(_hatsData.hats);

        __Ownable_init();

        _initHatTree(_owner, hatsStrings, hatsAddresses);

        transferOwnership(_owner);
    }

    function updateHatsAddress(address newHatsAddress) external onlyOwner {
        _hatsData.hats = newHatsAddress;
        emit HatsAddressUpdated(newHatsAddress);
    }

    function updateCharacterHatModuleImplementationAddress(address newCharacterHatAddress) external onlyOwner {
        _hatsData.characterHatEligibilityModuleImplementation = newCharacterHatAddress;
        emit CharacterHatEligibilityModuleAddressUpdated(newCharacterHatAddress);
    }

    function updatePlayerHatModuleImplementationAddress(address newPlayerAddress) external onlyOwner {
        _hatsData.playerHatEligibilityModuleImplementation = newPlayerAddress;
        emit PlayerHatEligibilityModuleAddressUpdated(newPlayerAddress);
    }

    function updateadminHatModuleImplementationAddress(address newadminAddress) external onlyOwner {
        _hatsData.adminHatEligibilityModuleImplementation = newadminAddress;
        emit AdminHatEligibilityModuleAddressUpdated(newadminAddress);
    }

    function updateDungeonMasterHatModuleImplementationAddress(address newDungeonMasterAddress) external onlyOwner {
        _hatsData.dungeonMasterHatEligibilityModuleImplementation = newDungeonMasterAddress;
        emit DungeonMasterHatEligibilityModuleAddressUpdated(newDungeonMasterAddress);
    }

    function updateAdminHatId(uint256 newAdminHatId) external onlyOwner {
        _hatsData.adminHatId = newAdminHatId;
        emit AdminHatIdUpdated(newAdminHatId);
    }

    function updateDungeonMasterHatId(uint256 newDungeonMasterHatId) external onlyOwner {
        _hatsData.dungeonMasterHatId = newDungeonMasterHatId;
        emit DungeonMasterHatIdUpdated(newDungeonMasterHatId);
    }

    function updatePlayerHatId(uint256 newPlayerHatId) external onlyOwner {
        _hatsData.playerHatId = newPlayerHatId;
        emit PlayerHatIdUpdated(newPlayerHatId);
    }

    function updateCharacterHatId(uint256 newCharacterHatId) external onlyOwner {
        _hatsData.characterHatId = newCharacterHatId;
        emit CharacterHatIdUpdated(newCharacterHatId);
    }

    function mintPlayerHat(address wearer) external returns (bool) {
        if (_hatsData.playerHatId == uint256(0)) {
            revert Errors.VariableNotSet();
        }
        (bool eligible,) = checkPlayerHatEligibility(wearer);

        if (!eligible) {
            revert Errors.PlayerError();
        }
        // look for emitted event from hats contract
        return _hats.mintHat(_hatsData.playerHatId, wearer);
    }

    function mintCharacterHat(address wearer) external returns (bool) {
        if (_hatsData.characterHatId == uint256(0)) {
            revert Errors.VariableNotSet();
        }
        (bool eligible,) = checkCharacterHatEligibility(wearer);
        if (!eligible) {
            revert Errors.CharacterError();
        }
        // look for emitted event from hats contract
        return _hats.mintHat(_hatsData.characterHatId, wearer);
    }

    function getHatsData() external view returns (HatsData memory) {
        return _hatsData;
    }

    function checkCharacterHatEligibility(address account) public view returns (bool eligible, bool standing) {
        return IHatsEligibility(characterHatEligibilityModule).getWearerStatus(account, _hatsData.characterHatId);
    }

    function checkPlayerHatEligibility(address account) public view returns (bool eligible, bool standing) {
        return IHatsEligibility(playerHatEligibilityModule).getWearerStatus(account, _hatsData.playerHatId);
    }

    function isCharacter(address wearer) public view returns (bool) {
        if (_hatsData.characterHatId == uint256(0)) {
            revert Errors.VariableNotSet();
        }
        return _hats.balanceOf(wearer, _hatsData.characterHatId) > 0;
    }

    function isPlayer(address wearer) public view returns (bool) {
        if (_hatsData.playerHatId == uint256(0)) {
            revert Errors.VariableNotSet();
        }
        return _hats.balanceOf(wearer, _hatsData.playerHatId) > 0;
    }

    function isDungeonMaster(address wearer) public view returns (bool) {
        if (_hatsData.dungeonMasterHatId == uint256(0)) {
            revert Errors.VariableNotSet();
        }
        return _hats.balanceOf(wearer, _hatsData.dungeonMasterHatId) > 0;
    }

    function _initHatTree(address _owner, bytes calldata hatsStrings, bytes calldata hatsAddresses)
        private
        returns (bool success)
    {
        if (
            address(_hats) == address(0) || _hatsData.characterHatEligibilityModuleImplementation == address(0)
                || _hatsData.playerHatEligibilityModuleImplementation == address(0)
                || _hatsData.adminHatEligibilityModuleImplementation == address(0)
                || _hatsData.dungeonMasterHatEligibilityModuleImplementation == address(0)
        ) {
            revert Errors.VariableNotSet();
        }

        //mint tophat to this contract
        _hatsData.topHatId = _initTopHat(hatsStrings);

        // create admin hats
        _initAdminHat(hatsStrings, hatsAddresses, _owner);

        //transfer topHat to owner
        _hats.transferHat(_hatsData.topHatId, address(this), _owner);

        // create dungeon master hats
        _initDungeonMasterHat(hatsStrings, hatsAddresses, _owner);
        // init player hats
        _initPlayerHat(hatsStrings, hatsAddresses, _owner);

        // init character hats
        _initCharacterHat(hatsStrings, hatsAddresses, _owner);

        success = true;
        return success;
    }

    function _initTopHat(bytes calldata hatsStrings) private returns (uint256 topHatId) {
        string memory topHatDescription;
        (_baseHatImgUri, topHatDescription,,,,,,,,) =
            abi.decode(hatsStrings, (string, string, string, string, string, string, string, string, string, string));
        topHatId = _hats.mintTopHat(address(this), topHatDescription, _baseHatImgUri);
    }

    function _initAdminHat(bytes calldata hatsStrings, bytes calldata hatsAddresses, address _owner)
        private
        returns (uint256 adminId)
    {
        string memory adminDescription;
        string memory adminUri;
        (,, adminUri, adminDescription,,,,,,) =
            abi.decode(hatsStrings, (string, string, string, string, string, string, string, string, string, string));

        bytes memory encodedAdmins;
        address[] memory newAdmins;

        {
            address[] memory admins;

            (,,,,,, admins,,,,) = abi.decode(
                hatsAddresses,
                (address, address, address, address, address, address, address[], address[], address, address, address)
            );

            // add this address to admins array
            newAdmins = new address[](admins.length + 1);

            for (uint256 i; i < admins.length; i++) {
                newAdmins[i] = admins[i];
            }

            //add this address to last place
            newAdmins[newAdmins.length - 1] = address(this);

            //re-encode array
            encodedAdmins = abi.encode(newAdmins);
        }

        // predict admin hat ID.
        adminId = _hats.getNextId(_hatsData.topHatId);

        // create admin hat Eligibility module
        adminHatEligibilityModule = _createAdminHatEligibilityModule(adminId, encodedAdmins);

        // create admin hat with eligibility module
        _hatsData.adminHatId = _hats.createHat(
            _hatsData.topHatId, adminDescription, MAX_SUPPLY, adminHatEligibilityModule, _owner, true, _baseHatImgUri
        );

        // check that predicted Id equals created Id
        assert(_hatsData.adminHatId == adminId);

        //mint admin hats for the admins
        for (uint256 i; i < newAdmins.length; i++) {
            _hats.mintHat(adminId, newAdmins[i]);
        }
    }

    function _createAdminHatEligibilityModule(uint256 adminId, bytes memory encodedAdmins) private returns (address) {
        bytes memory encodedHatsAddress = abi.encode(_hatsData.hats);
        return HatsModuleFactory(_hatsData.hatsModuleFactory).createHatsModule(
            _hatsData.adminHatEligibilityModuleImplementation, adminId, encodedHatsAddress, encodedAdmins
        );
    }

    function _initDungeonMasterHat(bytes calldata hatsStrings, bytes calldata hatsAddresses, address _owner)
        private
        returns (uint256 dungeonMasterId)
    {
        string memory dungeonMasterDescription;
        string memory dungeonMasterUri;
        (,,,, dungeonMasterUri, dungeonMasterDescription,,,,) =
            abi.decode(hatsStrings, (string, string, string, string, string, string, string, string, string, string));

        address[] memory dungeonMasters;

        (,,,,,,, dungeonMasters,,,) = abi.decode(
            hatsAddresses,
            (address, address, address, address, address, address, address[], address[], address, address, address)
        );

        // predict dungeonMaster hat ID.
        dungeonMasterId = _hats.getNextId(_hatsData.adminHatId);
        // encode dungeon masters array for module creation
        bytes memory encodedDungeonMasters = abi.encode(dungeonMasters);
        // create dungeonMaster hat Eligibility module
        dungeonMasterHatEligibilityModule =
            _createDungeonMasterHatEligibilityModule(dungeonMasterId, encodedDungeonMasters);

        // create dungeonMaster hat with eligibility module
        _hatsData.dungeonMasterHatId = _hats.createHat(
            _hatsData.adminHatId,
            dungeonMasterDescription,
            MAX_SUPPLY,
            dungeonMasterHatEligibilityModule,
            _owner,
            true,
            dungeonMasterUri
        );

        //check that Ids match
        assert(_hatsData.dungeonMasterHatId == dungeonMasterId);

        //mint dungeonMaster hats for the dungeonMasters
        for (uint256 i; i < dungeonMasters.length; i++) {
            _hats.mintHat(dungeonMasterId, dungeonMasters[i]);
        }
    }

    function _createDungeonMasterHatEligibilityModule(uint256 dungeonMasterId, bytes memory dungeonMasters)
        private
        returns (address)
    {
        bytes memory encodedHatsAddress = abi.encode(_hatsData.hats);
        return HatsModuleFactory(_hatsData.hatsModuleFactory).createHatsModule(
            _hatsData.dungeonMasterHatEligibilityModuleImplementation,
            dungeonMasterId,
            encodedHatsAddress,
            dungeonMasters
        );
    }

    function _initPlayerHat(bytes calldata hatsStrings, bytes calldata hatsAddresses, address _owner)
        private
        returns (uint256 playerHatId)
    {
        (,,,,,, string memory playerUri, string memory playerDescription,,) =
            abi.decode(hatsStrings, (string, string, string, string, string, string, string, string, string, string));

        (,,,,,,,, address characterSheets,,) = abi.decode(
            hatsAddresses,
            (address, address, address, address, address, address, address[], address[], address, address, address)
        );
        playerHatId = _hats.getNextId(_hatsData.dungeonMasterHatId);

        playerHatEligibilityModule = _createPlayerHatEligibilityModule(playerHatId, characterSheets);

        _hatsData.playerHatId = _hats.createHat(
            _hatsData.dungeonMasterHatId,
            playerDescription,
            MAX_SUPPLY,
            playerHatEligibilityModule,
            _owner,
            true,
            playerUri
        );

        assert(_hatsData.playerHatId == playerHatId);

        return playerHatId;
    }

    function _initCharacterHat(bytes calldata hatsStrings, bytes calldata hatsAddresses, address _owner)
        private
        returns (uint256 characterHatId)
    {
        (,,,,,,,, string memory characterUri, string memory characterDescription) =
            abi.decode(hatsStrings, (string, string, string, string, string, string, string, string, string, string));

        (,,,,,,,, address characterSheets, address erc6551Registry, address erc6551Account) = abi.decode(
            hatsAddresses,
            (address, address, address, address, address, address, address[], address[], address, address, address)
        );
        characterHatId = _hats.getNextId(_hatsData.dungeonMasterHatId);

        characterHatEligibilityModule =
            _createCharacterHatEligibilityModule(characterHatId, characterSheets, erc6551Registry, erc6551Account);

        _hatsData.characterHatId = _hats.createHat(
            _hatsData.dungeonMasterHatId,
            characterDescription,
            MAX_SUPPLY,
            characterHatEligibilityModule,
            _owner,
            true,
            characterUri
        );

        assert(_hatsData.characterHatId == characterHatId);

        return characterHatId;
    }

    function _createCharacterHatEligibilityModule(
        uint256 characterHatId,
        address characterSheets,
        address erc6551Registry,
        address erc6551AccountImplementation
    ) private returns (address) {
        if (
            _hatsData.hatsModuleFactory == address(0)
                || _hatsData.characterHatEligibilityModuleImplementation == address(0)
        ) {
            revert Errors.VariableNotSet();
        }
        bytes memory characterModuleData =
            abi.encodePacked(erc6551Registry, erc6551AccountImplementation, characterSheets);
        address characterHatsModule = HatsModuleFactory(_hatsData.hatsModuleFactory).createHatsModule(
            _hatsData.characterHatEligibilityModuleImplementation, characterHatId, characterModuleData, ""
        );
        return characterHatsModule;
    }

    function _createPlayerHatEligibilityModule(uint256 playerHatId, address characterSheets)
        private
        returns (address)
    {
        if (
            _hatsData.hatsModuleFactory == address(0)
                || _hatsData.playerHatEligibilityModuleImplementation == address(0)
        ) {
            revert Errors.VariableNotSet();
        }
        bytes memory playerModuleData = abi.encodePacked(characterSheets, uint256(1));
        address playerHatsModule = HatsModuleFactory(_hatsData.hatsModuleFactory).createHatsModule(
            _hatsData.playerHatEligibilityModuleImplementation, playerHatId, playerModuleData, ""
        );
        return playerHatsModule;
    }

    function _authorizeUpgrade(address newImplementation) internal virtual override onlyOwner {}
}
