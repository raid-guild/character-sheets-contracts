// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {UUPSUpgradeable} from "openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import {IHats} from "hats-protocol/Interfaces/IHats.sol";
import {ERC1155HolderUpgradeable} from
    "openzeppelin-contracts-upgradeable/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";
import {IHatsEligibility} from "hats-protocol/Interfaces/IHatsEligibility.sol";
import {IAddressEligibilityModule} from "../interfaces/IAddressEligibilityModule.sol";
import {HatsModuleFactory} from "hats-module/HatsModuleFactory.sol";
import {ImplementationAddressStorage} from "../ImplementationAddressStorage.sol";
import {IClonesAddressStorage} from "../interfaces/IClonesAddressStorage.sol";

import {Errors} from "../lib/Errors.sol";
import {HatsData} from "../lib/Structs.sol";

import "forge-std/console2.sol";

/**
 * @title Hats Adaptor
 * @author MrDeadCe11
 * @notice This is an adaptor that will automatically create the appropriate hat tree for the
 * character sheets contacts.  It also allows the minting of hats to players and characters
 * and checks if any address is wearing the player or character hat.
 */

struct InitStruct {
    address _owner;
    bytes hatsAddresses;
    bytes hatsStrings;
    bytes customModuleImplementations;
}

contract HatsAdaptor is Initializable, OwnableUpgradeable, UUPSUpgradeable, ERC1155HolderUpgradeable {
    HatsData private _hatsData;

    IHats private _hats;

    /**
     * @notice these are the addresses of the eligibility modules after they are created by
     * the hats module factory during contract initialization.
     */

    ImplementationAddressStorage public implementations;
    IClonesAddressStorage public clones;

    address public adminHatEligibilityModule;
    address public gameMasterHatEligibilityModule;
    address public playerHatEligibilityModule;
    address public characterHatEligibilityModule;

    /**
     * @notice the max hat supply is set to uint32 max for now.  can be changed down the line.
     */
    uint32 public constant MAX_SUPPLY = type(uint32).max - 1;

    string private _baseHatImgUri;

    event AdminHatIdUpdated(uint256 newAdminHatId);
    event GameMasterHatIdUpdated(uint256 newGameMasterHatId);
    event PlayerHatIdUpdated(uint256 newPlayerHatId);
    event CharacterHatIdUpdated(uint256 newCharacterHatId);
    event HatsUpdated(address newHats);
    event ImplementationAddressStorageUpdated(address newImplementations);
    event GameMasterHatEligibilityModuleUpdated(address newGameMasterHatEligibilityModule);
    event PlayerHatEligibilityModuleUpdated(address newPlayerHatEligibilityModule);
    event CharacterHatEligibilityModuleUpdated(address newCharacterHatEligibilityModule);
    event AdminEligibilityModuleUpdated(address newAdminEligibilityModule);
    event HatTreeInitialized(address owner, bytes hatsAddresses, bytes hatsStrings, bytes customModuleImplementations);

    modifier onlyAdmin() {
        if (!_hats.isWearerOfHat(msg.sender, _hatsData.adminHatId)) {
            revert Errors.AdminOnly();
        }
        _;
    }

    constructor() {
        _disableInitializers();
    }

    /**
     * @notice call this function if you want to initialize with default Hats Eligibility modules.
     * for custom modules see the other initializer below.
     * HATS ADDRESSES
     *        1.  address[]  admins
     *        2.  address[] dungeon masters
     *        3.  address implementations
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
        bytes memory customModuleImplementation = abi.encode(address(0), address(0), address(0), address(0));
        return _initialize(_owner, hatsAddresses, hatsStrings, customModuleImplementation);
    }

    /**
     * @notice call this function if you want to initialize with custom eligibility modules.
     * custom module implementations
     *  1. admin hats eligibility Module enter address of custom implementation, or enter address(0) to use default.
     *  2. gamemaster admin hats eligibility Module
     *  3. player admin hats eligibility Module
     *  4. character admin hats eligibility Module
     */

    function initialize(
        address _owner,
        bytes calldata hatsAddresses,
        bytes calldata hatsStrings,
        bytes calldata customModuleImplementations
    ) external initializer {
        return _initialize(_owner, hatsAddresses, hatsStrings, customModuleImplementations);
    }

    function updateImplementations(address newImplementations) external onlyOwner {
        implementations = ImplementationAddressStorage(newImplementations);
        emit ImplementationAddressStorageUpdated(newImplementations);
    }

    function updateAdminHatId(uint256 newAdminHatId) external onlyOwner {
        _hatsData.adminHatId = newAdminHatId;
        emit AdminHatIdUpdated(newAdminHatId);
    }

    function updateGameMasterHatId(uint256 newGameMasterHatId) external onlyOwner {
        _hatsData.gameMasterHatId = newGameMasterHatId;
        emit GameMasterHatIdUpdated(newGameMasterHatId);
    }

    function updatePlayerHatId(uint256 newPlayerHatId) external onlyOwner {
        _hatsData.playerHatId = newPlayerHatId;
        emit PlayerHatIdUpdated(newPlayerHatId);
    }

    /// @notice the following update functions will use the base implementation addresses stored in the implementationAddressStorage contract.

    function updateAdminEligibilityModule(uint256 adminId, bytes calldata encodedAdmins, address adminImplementation)
        external
        onlyOwner
    {
        adminHatEligibilityModule = _createAdminHatEligibilityModule(adminId, encodedAdmins, adminImplementation);
        emit AdminEligibilityModuleUpdated(adminHatEligibilityModule);
    }

    function updateGameMasterHatEligibilityModule(
        uint256 gameMasterId,
        bytes calldata gameMasters,
        address dmImplementation
    ) external onlyOwner {
        gameMasterHatEligibilityModule =
            _createGameMasterHatEligibilityModule(gameMasterId, gameMasters, dmImplementation);
        emit GameMasterHatEligibilityModuleUpdated(gameMasterHatEligibilityModule);
    }

    function updatePlayerHatEligibilityModule(
        uint256 playerHatId,
        address characterSheets,
        address playerImplementation
    ) external onlyOwner {
        playerHatEligibilityModule =
            _createPlayerHatEligibilityModule(playerHatId, characterSheets, playerImplementation);
        emit PlayerHatEligibilityModuleUpdated(playerHatEligibilityModule);
    }

    function updateCharacterHatEligibilityModule(uint256 characterHatId, address characterImplementation)
        external
        onlyOwner
    {
        characterHatEligibilityModule = _createCharacterHatEligibilityModule(characterHatId, characterImplementation);
        emit CharacterHatEligibilityModuleUpdated(characterHatEligibilityModule);
    }

    function updateHats(address newHats) external onlyOwner {
        _hats = IHats(newHats);
        emit HatsUpdated(newHats);
    }

    function addGameMasters(address[] calldata newGameMasters) external onlyAdmin {
        IAddressEligibilityModule(gameMasterHatEligibilityModule).addEligibleAddresses(newGameMasters);
        //check eligibility module for emitted event
        for (uint256 i = 0; i < newGameMasters.length; i++) {
            _ifNotHatMint(newGameMasters[i], _hatsData.gameMasterHatId);
        }
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

    function isGameMaster(address wearer) public view returns (bool) {
        if (_hatsData.gameMasterHatId == uint256(0)) {
            revert Errors.VariableNotSet();
        }
        return _hats.balanceOf(wearer, _hatsData.gameMasterHatId) > 0;
    }

    function _ifNotHatMint(address wearer, uint256 hatId) internal {
        if (!_hats.isWearerOfHat(wearer, hatId)) {
            _hats.mintHat(hatId, wearer);
        }
    }

    //solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address newImplementation) internal virtual override onlyOwner {}

    function _initialize(
        address _owner,
        bytes calldata hatsAddresses,
        bytes calldata hatsStrings,
        bytes memory customModuleImplementations
    ) private {
        (,, address _implementations, address _clonesStorage) =
            abi.decode(hatsAddresses, (address[], address[], address, address));

        implementations = ImplementationAddressStorage(_implementations);
        clones = IClonesAddressStorage(_clonesStorage);
        _hats = IHats(implementations.hatsContract());

        // init struct because STACC TOO DANK!
        InitStruct memory initStruct;
        initStruct._owner = _owner;
        initStruct.hatsAddresses = hatsAddresses;
        initStruct.hatsStrings = hatsStrings;
        initStruct.customModuleImplementations = customModuleImplementations;

        __Ownable_init(_owner);

        _initHatTree(initStruct);
    }

    function _initHatTree(InitStruct memory _initStruct) private returns (bool) {
        if (address(_hats) == address(0) || address(implementations) == address(0)) {
            revert Errors.VariableNotSet();
        }

        //mint tophat to this contract
        _hatsData.topHatId = _initTopHat(_initStruct.hatsStrings);

        // create admin hats
        _initAdminHat(
            _initStruct.hatsStrings,
            _initStruct.hatsAddresses,
            _initStruct._owner,
            _initStruct.customModuleImplementations
        );

        //transfer topHat to owner
        _hats.transferHat(_hatsData.topHatId, address(this), _initStruct._owner);

        // create game master hats
        _initGameMasterHat(
            _initStruct.hatsStrings,
            _initStruct.hatsAddresses,
            _initStruct._owner,
            _initStruct.customModuleImplementations
        );
        // init player hats
        _initPlayerHat(_initStruct.hatsStrings, _initStruct._owner, _initStruct.customModuleImplementations);

        // init character hats
        _initCharacterHat(_initStruct.hatsStrings, _initStruct._owner, _initStruct.customModuleImplementations);

        emit HatTreeInitialized(
            _initStruct._owner,
            _initStruct.hatsAddresses,
            _initStruct.hatsStrings,
            _initStruct.customModuleImplementations
        );
        return true;
    }

    function _initTopHat(bytes memory hatsStrings) private returns (uint256 topHatId) {
        string memory topHatDescription;
        (_baseHatImgUri, topHatDescription,,,,,,,,) =
            abi.decode(hatsStrings, (string, string, string, string, string, string, string, string, string, string));
        topHatId = _hats.mintTopHat(address(this), topHatDescription, _baseHatImgUri);
    }

    function _initAdminHat(
        bytes memory hatsStrings,
        bytes memory hatsAddresses,
        address _owner,
        bytes memory customModuleImplementations
    ) private returns (uint256 adminId) {
        string memory adminDescription;
        string memory adminUri;
        (,, adminUri, adminDescription,,,,,,) =
            abi.decode(hatsStrings, (string, string, string, string, string, string, string, string, string, string));

        bytes memory encodedAdmins;
        address[] memory newAdmins;

        (address customAdminModule,,,) = abi.decode(customModuleImplementations, (address, address, address, address));

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
        adminHatEligibilityModule = _createAdminHatEligibilityModule(adminId, encodedAdmins, customAdminModule);

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

    function _createAdminHatEligibilityModule(uint256 adminId, bytes memory encodedAdmins, address customAdminModule)
        private
        returns (address)
    {
        bytes memory encodedHatsAddress = abi.encode(implementations.hatsContract());
        customAdminModule =
            customAdminModule == address(0) ? implementations.addressHatsEligibilityModule() : customAdminModule;

        return HatsModuleFactory(implementations.hatsModuleFactory()).createHatsModule(
            customAdminModule, adminId, encodedHatsAddress, encodedAdmins
        );
    }

    function _initGameMasterHat(
        bytes memory hatsStrings,
        bytes memory hatsAddresses,
        address _owner,
        bytes memory customModuleImplementations
    ) private returns (uint256 gameMasterId) {
        string memory gameMasterDescription;
        string memory gameMasterUri;
        (,,,, gameMasterUri, gameMasterDescription,,,,) =
            abi.decode(hatsStrings, (string, string, string, string, string, string, string, string, string, string));

        address[] memory gameMasters;

        (, gameMasters,) = abi.decode(hatsAddresses, (address[], address[], address));

        (, address customDmModule,,) = abi.decode(customModuleImplementations, (address, address, address, address));

        // predict gameMaster hat ID.
        gameMasterId = _hats.getNextId(_hatsData.adminHatId);
        // encode game masters array for module creation
        bytes memory encodedGameMasters = abi.encode(gameMasters);
        // create gameMaster hat Eligibility module
        gameMasterHatEligibilityModule =
            _createGameMasterHatEligibilityModule(gameMasterId, encodedGameMasters, customDmModule);

        // create gameMaster hat with eligibility module
        _hatsData.gameMasterHatId = _hats.createHat(
            _hatsData.adminHatId,
            gameMasterDescription,
            MAX_SUPPLY,
            gameMasterHatEligibilityModule,
            _owner,
            true,
            gameMasterUri
        );

        //check that Ids match
        assert(_hatsData.gameMasterHatId == gameMasterId);

        //mint gameMaster hats for the gameMasters
        for (uint256 i; i < gameMasters.length; i++) {
            _hats.mintHat(gameMasterId, gameMasters[i]);
        }
    }

    function _createGameMasterHatEligibilityModule(
        uint256 gameMasterId,
        bytes memory gameMasters,
        address customDmModule
    ) private returns (address) {
        bytes memory encodedHatsAddress = abi.encode(implementations.hatsContract());

        customDmModule = customDmModule == address(0) ? implementations.addressHatsEligibilityModule() : customDmModule;

        return HatsModuleFactory(implementations.hatsModuleFactory()).createHatsModule(
            customDmModule, gameMasterId, encodedHatsAddress, gameMasters
        );
    }

    function _initPlayerHat(bytes memory hatsStrings, address _owner, bytes memory customModuleImplementations)
        private
        returns (uint256 playerHatId)
    {
        (,,,,,, string memory playerUri, string memory playerDescription,,) =
            abi.decode(hatsStrings, (string, string, string, string, string, string, string, string, string, string));

        playerHatId = _hats.getNextId(_hatsData.gameMasterHatId);

        (,, address customPlayerModule,) = abi.decode(customModuleImplementations, (address, address, address, address));

        playerHatEligibilityModule =
            _createPlayerHatEligibilityModule(playerHatId, clones.characterSheets(), customPlayerModule);

        _hatsData.playerHatId = _hats.createHat(
            _hatsData.gameMasterHatId,
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

    function _initCharacterHat(bytes memory hatsStrings, address _owner, bytes memory customModuleImplementations)
        private
        returns (uint256 characterHatId)
    {
        (,,,,,,,, string memory characterUri, string memory characterDescription) =
            abi.decode(hatsStrings, (string, string, string, string, string, string, string, string, string, string));
        (,,, address customCharacterModule) =
            abi.decode(customModuleImplementations, (address, address, address, address));
        characterHatId = _hats.getNextId(_hatsData.gameMasterHatId);

        characterHatEligibilityModule = _createCharacterHatEligibilityModule(characterHatId, customCharacterModule);

        _hatsData.characterHatId = _hats.createHat(
            _hatsData.gameMasterHatId,
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

    function _createCharacterHatEligibilityModule(uint256 characterHatId, address customCharacterModule)
        private
        returns (address)
    {
        if (
            implementations.hatsModuleFactory() == address(0)
                || implementations.erc6551HatsEligibilityModule() == address(0)
        ) {
            revert Errors.VariableNotSet();
        }
        bytes memory characterModuleData = abi.encodePacked(
            implementations.erc6551Registry(), implementations.erc6551AccountImplementation(), clones.characterSheets()
        );
        customCharacterModule =
            customCharacterModule == address(0) ? implementations.erc6551HatsEligibilityModule() : customCharacterModule;
        address characterHatsModule = HatsModuleFactory(implementations.hatsModuleFactory()).createHatsModule(
            customCharacterModule, characterHatId, characterModuleData, ""
        );
        return characterHatsModule;
    }

    function _createPlayerHatEligibilityModule(uint256 playerHatId, address characterSheets, address customPlayerModule)
        private
        returns (address)
    {
        if (
            implementations.hatsModuleFactory() == address(0)
                || implementations.erc721HatsEligibilityModule() == address(0)
        ) {
            revert Errors.VariableNotSet();
        }

        bytes memory playerModuleData = abi.encodePacked(characterSheets, uint256(1));
        customPlayerModule =
            customPlayerModule == address(0) ? implementations.erc721HatsEligibilityModule() : customPlayerModule;
        address playerHatsModule = HatsModuleFactory(implementations.hatsModuleFactory()).createHatsModule(
            customPlayerModule, playerHatId, playerModuleData, ""
        );
        return playerHatsModule;
    }
}
