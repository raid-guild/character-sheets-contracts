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
import {HatsAdaptor} from "./adaptors/HatsAdaptor.sol";

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
     *     @return (clonesAddressStorage)  this is the data needed to pass into the initialize function to initialize all the contracts.
     */
    function create(address dao, address _classLevelAdaptorImplementation) external returns (address) {
        address clonesAddressStorage = createClonesStorage();
        address itemsManagerClone = createItemsManager();
        address hatsAdaptorClone = createHatsAdaptor();

        address characterEligibilityAdaptorClone = dao != address(0) ? createCharacterEligibilityAdaptor() : address(0);

        (address characterSheetsClone, address itemsClone) = _createSheetsAndItems();

        (address classesClone, address experienceClone, address classLevelAdaptorClone) =
            _createClassesAndExperience(_classLevelAdaptorImplementation);

        bytes memory encodedCloneAddresses =
            abi.encode(characterSheetsClone, itemsClone, itemsManagerClone, classesClone, experienceClone);

        bytes memory encodedAdaptorAddresses =
            abi.encode(characterEligibilityAdaptorClone, classLevelAdaptorClone, hatsAdaptorClone);

        // initialize clones address storage contract
        IClonesAddressStorage(clonesAddressStorage).initialize(encodedCloneAddresses, encodedAdaptorAddresses);

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
     * @notice This will initialize all the contracts
     * @dev this function should be called immediately after all the create functions have been called
     * @param clonesStorageAddress the address of the cloned ClonesAddressStorage contract.
     * @param dao the address of the dao who's membership will restrict character sheets eligibility.  address(0) for no dao restriction;
     * @param encodedHatsAddresses this will be the hats adaptor initialization data
     *          -- address[] admins the list of addresses that will have admin priviledges
     *          -- address[] dungeonMasters the list of addresses that will have dungeonMasterpriviledges
     *          -- address Implementations the address of the ImplementationAddressStorage contract
     *
     * @param encodedHatsStrings the encoded strings needed for the hats adaptor init.
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
     *
     * @param data encoded string data strings to include must be in this order:
     * - the base metadata uri for the character sheets clone
     * - the base character token uri for the character sheets clone
     * - the base uri for the ITEMS clone
     * - the base uri for the CLASSES clone
     */
    function initializeContracts(
        address clonesStorageAddress,
        address dao,
        bytes calldata encodedHatsAddresses,
        bytes calldata encodedHatsStrings,
        bytes calldata data
    ) public {
        IClonesAddressStorage clones = IClonesAddressStorage(clonesStorageAddress);

        //stacc too dank
        CharacterEligibilityAdaptor(clones.characterEligibilityAdaptorClone()).initialize(msg.sender, dao);
        ClassLevelAdaptor(clones.classLevelAdaptorClone()).initialize(clonesStorageAddress);
        HatsAdaptor(clones.hatsAdaptorClone()).initialize(msg.sender, encodedHatsAddresses, encodedHatsStrings);

        CharacterSheetsImplementation(clones.characterSheetsClone()).initialize(
            _encodeCharacterInitData(clonesStorageAddress, data)
        );

        ItemsImplementation(clones.itemsClone()).initialize(_encodeItemsData(clonesStorageAddress, data));

        ClassesImplementation(clones.classesClone()).initialize(_encodeClassesData(clonesStorageAddress, data));
        ItemsManagerImplementation(clones.itemsManagerClone()).initialize(clonesStorageAddress);
        ExperienceImplementation(clones.experienceClone()).initialize(clonesStorageAddress);
    }

    function _createSheetsAndItems() private returns (address, address) {
        address characterSheetsClone = createCharacterSheets();
        address itemsClone = createItems();

        // bytes memory encodedCharInitAddresses = abi.encode(cloneAddressStorage, address(implementations));

        // CharacterSheetsImplementation(characterSheetsClone).initialize(
        //     _encodeCharacterInitData(encodedCharInitAddresses, data)
        // );

        // if (dao != address(0)) {
        //     CharacterEligibilityAdaptor(characterEligibilityAdaptorClone).initialize(msg.sender, dao);
        // }

        return (characterSheetsClone, itemsClone);
    }

    function _createClassesAndExperience(address _classLevelAdaptorImplementation)
        private
        returns (address, address, address)
    {
        address experienceClone = createExperience();
        address classesClone = createClasses();
        address classLevelAdaptorClone = _classLevelAdaptorImplementation == address(0)
            ? createClassLevelAdaptor()
            : createClassLevelAdaptor(_classLevelAdaptorImplementation);

        return (classesClone, experienceClone, classLevelAdaptorClone);
    }

    function _encodeCharacterInitData(address clonesStorage, bytes memory data) private view returns (bytes memory) {
        (string memory characterSheetsMetadataUri, string memory characterSheetsBaseUri,,) = _decodeStrings(data);

        bytes memory encodedCharacterSheetParameters =
            abi.encode(clonesStorage, address(implementations), characterSheetsMetadataUri, characterSheetsBaseUri);

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
