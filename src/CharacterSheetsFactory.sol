pragma solidity ^0.8.19;
// SPDX-License-Identifier: MIT

import {OwnableUpgradeable} from "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import {ERC1967Proxy} from "openzeppelin-contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ImplementationAddressStorage} from "./lib/ImplementationAddressStorage.sol";

import {IClonesAddressStorage} from "./interfaces/IClonesAddressStorage.sol";

import {CharacterSheetsImplementation} from "./implementations/CharacterSheetsImplementation.sol";
import {ClassesImplementation} from "./implementations/ClassesImplementation.sol";
import {ExperienceImplementation} from "./implementations/ExperienceImplementation.sol";
import {ItemsImplementation} from "./implementations/ItemsImplementation.sol";
import {CharacterEligibilityAdaptor} from "./adaptors/CharacterEligibilityAdaptor.sol";
import {ClassLevelAdaptor} from "./adaptors/ClassLevelAdaptor.sol";
import {ItemsManagerImplementation} from "./implementations/ItemsManagerImplementation.sol";

import {IERC165} from "openzeppelin-contracts/utils/introspection/IERC165.sol";

import {Errors} from "./lib/Errors.sol";

// import "forge-std/console2.sol";

contract CharacterSheetsFactory is Initializable, OwnableUpgradeable {
    // address storage

    ImplementationAddressStorage public implementations;

    bytes4 public constant ELIGIBILITY_INTERFACE_ID = 0x671ccc5a;
    bytes4 public constant CLASS_LEVELS_INTERFACE_ID = 0xfe211eb1;

    event NewGameStarted(address creator, address clonesAddressStorage);
    event ImplementationAddressStorageUpdated(address newImplementationAddressStorage);

    constructor() {
        _disableInitializers();
    }

    function initialize(address _implementationAddressStorage) external initializer {
        __Context_init_unchained();
        __Ownable_init_unchained(msg.sender);
        implementations = ImplementationAddressStorage(_implementationAddressStorage);
    }

    function updateImplementationAddressStorage(address _implementationAddressStorage) external onlyOwner {
        implementations = ImplementationAddressStorage(_implementationAddressStorage);
        emit ImplementationAddressStorageUpdated(_implementationAddressStorage);
    }

    /// create functions must be called first before the initialize call is made

    /**
     * @dev create function for all contracts and adaptors
     *     @param dao the address of a dao to be used with the character sheets elegibility adaptor pass in address(0) to have no elegibilty limitations
     *     @param _classLevelAdaptorImplementation the class Level adaptor address to be used.  pass in address(0) to use the default adaptor with D&D style leveling requirements
     *     @param data the encoded bytes of the correct initilization data see init function notes for correct data to be encoded
     */
    function create(address dao, address _classLevelAdaptorImplementation, bytes calldata data)
        external
        returns (address)
    {
        address clonesAddressStorage = createClonesStorage();
        address itemsManagerClone = createItemsManager();
        address hatsAdaptorClone = createHatsAdaptor();
        (address characterSheetsClone, address itemsClone, address CharacterEligibilityAdaptorClone) =
            _createSheetsAndItems(dao, clonesAddressStorage, data);

        (address classesClone, address experienceClone, address classLevelAdaptorClone) =
            _createClassesAndExperience(clonesAddressStorage, _classLevelAdaptorImplementation, data);

        bytes memory encodedAddresses = abi.encode(
            characterSheetsClone,
            itemsClone,
            itemsManagerClone,
            classesClone,
            experienceClone,
            CharacterEligibilityAdaptorClone,
            classLevelAdaptorClone,
            hatsAdaptorClone
        );

        IClonesAddressStorage(clonesAddressStorage).initialize(encodedAddresses);

        // initializeContracts(clonesAddressStorage, encodedAddresses, data);

        emit NewGameStarted(msg.sender, clonesAddressStorage);

        return (clonesAddressStorage);
    }

    function createExperience() public returns (address) {
        if (implementations.experienceImplementation() == address(0)) {
            revert Errors.NotInitialized();
        }

        address experienceClone = address(new ERC1967Proxy(implementations.experienceImplementation(), ""));

        return experienceClone;
    }

    function createCharacterSheets() public returns (address) {
        if (implementations.characterSheetsImplementation() == address(0)) {
            revert Errors.NotInitialized();
        }

        address characterSheetsClone = address(new ERC1967Proxy(implementations.characterSheetsImplementation(), ""));

        return characterSheetsClone;
    }

    function createItemsManager() public returns (address) {
        if (implementations.itemsManagerImplementation() == address(0)) {
            revert Errors.NotInitialized();
        }
        address itemsManager = address(new ERC1967Proxy(implementations.itemsManagerImplementation(), ""));
        return itemsManager;
    }

    function createItems() public returns (address) {
        if (implementations.itemsImplementation() == address(0)) {
            revert Errors.NotInitialized();
        }
        address itemsClone = address(new ERC1967Proxy(implementations.itemsImplementation(), ""));
        return itemsClone;
    }

    function createClasses() public returns (address) {
        if (implementations.classesImplementation() == address(0)) {
            revert Errors.NotInitialized();
        }
        address classesClone = address(new ERC1967Proxy(implementations.classesImplementation(), ""));
        return classesClone;
    }

    function createCharacterEligibilityAdaptor() public returns (address) {
        if (implementations.characterEligibilityAdaptorImplementation() == address(0)) {
            revert Errors.NotInitialized();
        }

        return createCharacterEligibilityAdaptor(implementations.characterEligibilityAdaptorImplementation());
    }

    function createCharacterEligibilityAdaptor(address _characterEligibilityAdaptorImplementation)
        public
        returns (address)
    {
        if (!IERC165(_characterEligibilityAdaptorImplementation).supportsInterface(ELIGIBILITY_INTERFACE_ID)) {
            revert Errors.UnsupportedInterface();
        }

        address characterEligibilityAdaptorClone =
            address(new ERC1967Proxy(_characterEligibilityAdaptorImplementation, ""));
        return characterEligibilityAdaptorClone;
    }

    function createClassLevelAdaptor() public returns (address) {
        if (implementations.classLevelAdaptorImplementation() == address(0)) {
            revert Errors.NotInitialized();
        }

        return createClassLevelAdaptor(implementations.classLevelAdaptorImplementation());
    }

    function createClassLevelAdaptor(address _classLevelAdaptorImplementation) public returns (address) {
        if (!IERC165(_classLevelAdaptorImplementation).supportsInterface(CLASS_LEVELS_INTERFACE_ID)) {
            revert Errors.UnsupportedInterface();
        }

        address classLevelAdaptorClone = address(new ERC1967Proxy(_classLevelAdaptorImplementation, ""));
        return classLevelAdaptorClone;
    }

    function createHatsAdaptor() public returns (address) {
        if (implementations.hatsAdaptorImplementation() == address(0)) {
            revert Errors.VariableNotSet();
        }

        return createHatsAdaptor(implementations.hatsAdaptorImplementation());
    }

    function createHatsAdaptor(address _hatsAdaptorImplementation) public returns (address) {
        address hatsAdaptor = address(new ERC1967Proxy(_hatsAdaptorImplementation, ""));
        return hatsAdaptor;
    }

    function createClonesStorage() public returns (address) {
        address clonesStorage = address(new ERC1967Proxy(implementations.cloneAddressStorage(), ""));
        return clonesStorage;
    }

    /**
     * @notice adaptors must be initialized seperately  ***************
     */

    /**
     * @notice This will initialize all the contracts except the adaptors
     * @dev this function should be called immediately after all the create functions have been called
     * @param encodedAddresses the encoded addresses must include in this order:
     * -eligibility adaptor clone address
     * - class level adaptor clone address
     * - dungeon masters: an array of addresses that will have dungeonMaster permission on the character sheets contract
     * - character sheets clone address to be initialized
     * - experience clone to address be initialized
     * - items clone address to be initialized
     * - classes clone address to be initialized
     * -
     * @param data encoded string data strings to include must be in this order:
     * - the base metadata uri for the character sheets clone
     * - the base character token uri for the character sheets clone
     * - the base uri for the ITEMS clone
     * - the base uri for the CLASSES clone
     */
    function initializeContracts(address clonesStorageAddress, bytes memory encodedAddresses, bytes calldata data)
        public
    {
        IClonesAddressStorage(clonesStorageAddress).initialize(encodedAddresses);
        IClonesAddressStorage clones = IClonesAddressStorage(clonesStorageAddress);
        //stacc too dank
        bytes memory encodedCharInitAddresses = abi.encode(clonesStorageAddress, address(implementations));

        CharacterSheetsImplementation(clones.characterSheetsClone()).initialize(
            _encodeCharacterInitData(encodedCharInitAddresses, data)
        );

        ItemsImplementation(clones.itemsClone()).initialize(_encodeItemsData(clonesStorageAddress, data));

        ClassesImplementation(clones.classesClone()).initialize(_encodeClassesData(clonesStorageAddress, data));
        ItemsManagerImplementation(clones.itemsManagerClone()).initialize(clonesStorageAddress);
        ExperienceImplementation(clones.experienceClone()).initialize(clonesStorageAddress);
    }

    function _createSheetsAndItems(address dao, address cloneAddressStorage, bytes calldata data)
        private
        returns (address, address, address)
    {
        address characterSheetsClone = createCharacterSheets();
        address itemsClone = createItems();

        address CharacterEligibilityAdaptorClone = dao != address(0) ? createCharacterEligibilityAdaptor() : address(0);

        bytes memory encodedCharInitAddresses = abi.encode(cloneAddressStorage, address(implementations));

        CharacterSheetsImplementation(characterSheetsClone).initialize(
            _encodeCharacterInitData(encodedCharInitAddresses, data)
        );

        if (dao != address(0)) {
            CharacterEligibilityAdaptor(CharacterEligibilityAdaptorClone).initialize(msg.sender, dao);
        }

        return (characterSheetsClone, itemsClone, CharacterEligibilityAdaptorClone);
    }

    function _createClassesAndExperience(
        address clonesAddressStorage,
        address _classLevelAdaptorImplementation,
        bytes calldata data
    ) private returns (address, address, address) {
        address experienceClone = createExperience();
        address classesClone = createClasses();
        address classLevelAdaptorClone = _classLevelAdaptorImplementation == address(0)
            ? createClassLevelAdaptor()
            : createClassLevelAdaptor(_classLevelAdaptorImplementation);

        ClassesImplementation(classesClone).initialize(_encodeClassesData(clonesAddressStorage, data));

        ClassLevelAdaptor(classLevelAdaptorClone).initialize(clonesAddressStorage);

        return (classesClone, experienceClone, classLevelAdaptorClone);
    }

    function _encodeCharacterInitData(bytes memory encodedInitData, bytes memory data)
        private
        view
        returns (bytes memory)
    {
        (string memory characterSheetsMetadataUri, string memory characterSheetsBaseUri,,) = _decodeStrings(data);

        (address clonesStorage, address implementationStorage) = abi.decode(encodedInitData, (address, address));

        bytes memory encodedCharacterSheetParameters =
            abi.encode(clonesStorage, implementationStorage, characterSheetsMetadataUri, characterSheetsBaseUri);

        return (encodedCharacterSheetParameters);
    }

    function _encodeItemsData(address clonesStorage, bytes memory data) private pure returns (bytes memory) {
        (,, string memory itemsBaseUri,) = _decodeStrings(data);

        return abi.encode(clonesStorage, itemsBaseUri);
    }

    function _encodeClassesData(address clonesStorage, bytes memory data) private pure returns (bytes memory) {
        (,,, string memory classesBaseUri) = _decodeStrings(data);
        return abi.encode(clonesStorage, classesBaseUri);
    }

    function _decodeStrings(bytes memory data)
        private
        pure
        returns (string memory, string memory, string memory, string memory)
    {
        (
            string memory characterSheetsMetadataUri,
            string memory characterSheetsBaseUri,
            string memory experienceBaseUri,
            string memory classesBaseUri
        ) = abi.decode(data, (string, string, string, string));
        return (characterSheetsMetadataUri, characterSheetsBaseUri, experienceBaseUri, classesBaseUri);
    }
}
