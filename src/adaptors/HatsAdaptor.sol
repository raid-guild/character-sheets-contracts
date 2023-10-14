// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {UUPSUpgradeable} from "openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import {IHats} from "hats-protocol/Interfaces/IHats.sol";
import {ERC1155HolderUpgradeable} from
    "openzeppelin-contracts-upgradeable/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";
import {IHatsEligibility} from "hats-protocol/Interfaces/IHatsEligibility.sol";
import {HatsModuleFactory} from "hats-module/HatsModuleFactory.sol";
import {ImplementationAddressStorage} from "../lib/ImplementationAddressStorage.sol";

import {Errors} from "../lib/Errors.sol";
import {HatsData} from "../lib/Structs.sol";

/**
 * @title Hats Adaptor
 * @author MrDeadCe11
 * @notice This is an adaptor that will automatically create the appropriate hat tree for the
 * character sheets   It also allows the minting of hats to players and characters
 * and checks if any address is wearing the player or character hat.
 */

contract HatsAdaptor is Initializable, OwnableUpgradeable, UUPSUpgradeable, ERC1155HolderUpgradeable {
    HatsData private _hatsData;

    IHats private _hats;

    /**
     * @notice these are the addresses of the eligibility modules after they are created by
     * the hats module factory during contract initialization.
     */

    ImplementationAddressStorage public implementations;

    address public adminHatEligibilityModule;
    address public dungeonMasterHatEligibilityModule;
    address public playerHatEligibilityModule;
    address public characterHatEligibilityModule;

    uint32 public constant MAX_SUPPLY = 200;

    string private _baseHatImgUri;

    event AdminHatIdUpdated(uint256 newAdminHatId);
    event DungeonMasterHatIdUpdated(uint256 newDungeonMasterHatId);
    event PlayerHatIdUpdated(uint256 newPlayerHatId);
    event CharacterHatIdUpdated(uint256 newCharacterHatId);
    event HatsUpdated(address newHats);
    event ImplementationAddressStorageUpdated(address newImplementations);
    event DungeonMasterHatEligibilityModuleUpdated(address newDungeonMasterHatEligibilityModule);
    event PlayerHatEligibilityModuleUpdated(address newPlayerHatEligibilityModule);
    event CharacterHatEligibilityModuleUpdated(address newCharacterHatEligibilityModule);
    event AdminEligibilityModuleUpdated(address newAdminEligibilityModule);

    constructor() {
        _disableInitializers();
    }

    /**
     * HATS ADDRESSES
     *        1.  address[]  admins
     *        2.  address[] dungeon masters
     *        3.  address implementations
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
        address _implementations;
        (,, _implementations) = abi.decode(hatsAddresses, (address[], address[], address));

        implementations = ImplementationAddressStorage(_implementations);
        _hats = IHats(implementations.hatsContract());

        __Ownable_init(_owner);

        _initHatTree(_owner, hatsStrings, hatsAddresses);
    }

    function updateImplementations(address newImplementations) external onlyOwner {
        implementations = ImplementationAddressStorage(newImplementations);
        emit ImplementationAddressStorageUpdated(newImplementations);
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

    /// @notice the following update functions will use the base implementation addresses stored in the implementationAddressStorage contract.

    function updateAdminEligibilityModule(uint256 adminId, bytes calldata encodedAdmins) external onlyOwner {
        adminHatEligibilityModule = _createAdminHatEligibilityModule(adminId, encodedAdmins);
        emit AdminEligibilityModuleUpdated(adminHatEligibilityModule);
    }

    function updateDungeonMasterHatEligibilityModule(uint256 dungeonMasterId, bytes calldata dungeonMasters)
        external
        onlyOwner
    {
        dungeonMasterHatEligibilityModule = _createDungeonMasterHatEligibilityModule(dungeonMasterId, dungeonMasters);
        emit DungeonMasterHatEligibilityModuleUpdated(dungeonMasterHatEligibilityModule);
    }

    function updatePlayerHatEligibilityModule(uint256 playerHatId, address characterSheets) external onlyOwner {
        playerHatEligibilityModule = _createPlayerHatEligibilityModule(playerHatId, characterSheets);
        emit PlayerHatEligibilityModuleUpdated(playerHatEligibilityModule);
    }

    function updateCharacterHatEligibilityModule(uint256 characterHatId) external onlyOwner {
        characterHatEligibilityModule = _createCharacterHatEligibilityModule(characterHatId);
        emit CharacterHatEligibilityModuleUpdated(characterHatEligibilityModule);
    }

    function updateHats(address newHats) external onlyOwner {
        _hats = IHats(newHats);
        emit HatsUpdated(newHats);
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

    function isAdmin(address wearer) public view returns (bool) {
        if (_hatsData.adminHatId == uint256(0)) {
            revert Errors.VariableNotSet();
        }
        return _hats.balanceOf(wearer, _hatsData.adminHatId) > 0;
    }

    function isDungeonMaster(address wearer) public view returns (bool) {
        if (_hatsData.dungeonMasterHatId == uint256(0)) {
            revert Errors.VariableNotSet();
        }
        return _hats.balanceOf(wearer, _hatsData.dungeonMasterHatId) > 0;
    }

    //solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address newImplementation) internal virtual override onlyOwner {}

    function _initHatTree(address _owner, bytes calldata hatsStrings, bytes calldata hatsAddresses)
        private
        returns (bool success)
    {
        if (
            address(_hats) == address(0) || implementations.characterHatsEligibilityModule() == address(0)
                || implementations.playerHatsEligibilityModule() == address(0)
                || implementations.adminHatsEligibilityModule() == address(0)
                || implementations.dungeonMasterHatsEligibilityModule() == address(0)
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
        _initPlayerHat(hatsStrings, _owner);

        // init character hats
        _initCharacterHat(hatsStrings, _owner);

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

            (admins,,) = abi.decode(hatsAddresses, (address[], address[], address));

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
        bytes memory encodedHatsAddress = abi.encode(implementations.hatsContract());
        return HatsModuleFactory(implementations.hatsModuleFactory()).createHatsModule(
            implementations.adminHatsEligibilityModule(), adminId, encodedHatsAddress, encodedAdmins
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

        (, dungeonMasters,) = abi.decode(hatsAddresses, (address[], address[], address));

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
        bytes memory encodedHatsAddress = abi.encode(implementations.hatsContract());
        return HatsModuleFactory(implementations.hatsModuleFactory()).createHatsModule(
            implementations.dungeonMasterHatsEligibilityModule(), dungeonMasterId, encodedHatsAddress, dungeonMasters
        );
    }

    function _initPlayerHat(bytes calldata hatsStrings, address _owner) private returns (uint256 playerHatId) {
        (,,,,,, string memory playerUri, string memory playerDescription,,) =
            abi.decode(hatsStrings, (string, string, string, string, string, string, string, string, string, string));

        playerHatId = _hats.getNextId(_hatsData.dungeonMasterHatId);

        playerHatEligibilityModule =
            _createPlayerHatEligibilityModule(playerHatId, implementations.characterSheetsImplementation());

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

    function _initCharacterHat(bytes calldata hatsStrings, address _owner) private returns (uint256 characterHatId) {
        (,,,,,,,, string memory characterUri, string memory characterDescription) =
            abi.decode(hatsStrings, (string, string, string, string, string, string, string, string, string, string));

        characterHatId = _hats.getNextId(_hatsData.dungeonMasterHatId);

        characterHatEligibilityModule = _createCharacterHatEligibilityModule(characterHatId);

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

    function _createCharacterHatEligibilityModule(uint256 characterHatId) private returns (address) {
        if (
            implementations.hatsModuleFactory() == address(0)
                || implementations.characterHatsEligibilityModule() == address(0)
        ) {
            revert Errors.VariableNotSet();
        }
        bytes memory characterModuleData = abi.encodePacked(
            implementations.erc6551Registry(),
            implementations.erc6551AccountImplementation(),
            implementations.characterSheetsImplementation()
        );
        address characterHatsModule = HatsModuleFactory(implementations.hatsModuleFactory()).createHatsModule(
            implementations.characterHatsEligibilityModule(), characterHatId, characterModuleData, ""
        );
        return characterHatsModule;
    }

    function _createPlayerHatEligibilityModule(uint256 playerHatId, address characterSheets)
        private
        returns (address)
    {
        if (
            implementations.hatsModuleFactory() == address(0)
                || implementations.playerHatsEligibilityModule() == address(0)
        ) {
            revert Errors.VariableNotSet();
        }
        bytes memory playerModuleData = abi.encodePacked(characterSheets, uint256(1));
        address playerHatsModule = HatsModuleFactory(implementations.hatsModuleFactory()).createHatsModule(
            implementations.playerHatsEligibilityModule(), playerHatId, playerModuleData, ""
        );
        return playerHatsModule;
    }
}
