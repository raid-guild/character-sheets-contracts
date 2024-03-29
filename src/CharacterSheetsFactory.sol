pragma solidity ^0.8.19;
// SPDX-License-Identifier: MIT

import {OwnableUpgradeable} from "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import {ERC1967Proxy} from "openzeppelin-contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ImplementationAddressStorage} from "./ImplementationAddressStorage.sol";

import {IClonesAddressStorage} from "./interfaces/IClonesAddressStorage.sol";

import {CharacterSheetsImplementation} from "./implementations/CharacterSheetsImplementation.sol";
import {ClassesImplementation} from "./implementations/ClassesImplementation.sol";
import {ExperienceImplementation} from "./implementations/ExperienceImplementation.sol";
import {ItemsImplementation} from "./implementations/ItemsImplementation.sol";
import {ICharacterEligibilityAdaptor} from "./interfaces/ICharacterEligibilityAdaptor.sol";
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

    event NewGameStarted(
        address starter, address clonesAddressStorage, bytes encodedHatsAddresses, bytes encodedHatsStrings
    );
    event NewGameCreated(address creator, address clonesAddressStorage);
    event ImplementationAddressStorageUpdated(address newImplementationAddressStorage);
    event ExperienceCreated(address experienceClone);
    event CharacterSheetsCreated(address characterSheetsClone);
    event ItemsCreated(address newItems);
    event ClassesCreated(address classesClone);
    event CharacterEligibilityAdaptorCreated(address characterEligibilityAdaptorClone);
    event ClassLevelAdaptorCreated(address classLevelAdaptorClone);

    function initialize(address _implementationAddressStorage) external initializer {
        __Context_init_unchained();
        __Ownable_init_unchained(msg.sender);
        implementations = ImplementationAddressStorage(_implementationAddressStorage);
    }

    function updateImplementationAddressStorage(address _implementationAddressStorage) external onlyOwner {
        implementations = ImplementationAddressStorage(_implementationAddressStorage);
        emit ImplementationAddressStorageUpdated(_implementationAddressStorage);
    }

    /**
     *     @notice creates all contracts and adaptors with default implementations
     *     @param dao the address of a dao to be used with the character sheets elegibility adaptor pass in address(0) to have no elegibilty limitations
     *     @return (clonesAddressStorage)  this is the data needed to pass into the initialize function to initialize all the contracts.
     */
    function create(address dao) public returns (address) {
        address clonesAddressStorage = createClonesStorage();
        address itemsManagerClone = createItemsManager();
        address hatsAdaptorClone = createHatsAdaptor();

        address characterEligibilityAdaptorClone = createCharacterEligibilityAdaptorFromDao(dao);
        (address characterSheetsClone, address itemsClone) = _createSheetsAndItems();

        (address classesClone, address experienceClone, address classLevelAdaptorClone) =
            _createClassesAndExperience(address(0));

        bytes memory encodedCloneAddresses =
            abi.encode(characterSheetsClone, itemsClone, itemsManagerClone, classesClone, experienceClone);

        bytes memory encodedAdaptorAddresses =
            abi.encode(characterEligibilityAdaptorClone, classLevelAdaptorClone, hatsAdaptorClone);

        // initialize clones address storage contract
        IClonesAddressStorage(clonesAddressStorage).initialize(encodedCloneAddresses, encodedAdaptorAddresses);

        emit NewGameCreated(msg.sender, clonesAddressStorage);

        return (clonesAddressStorage);
    }

    /**
     *    @notice this function will call both the create and initializeContracts functions
     *    @dev check notes on the initializeContracts function to see what needs to be
     *     in the encoded hatsStrings and the encoded sheets strings
     */
    function createAndInitialize(
        address dao,
        address[] calldata admins,
        address[] calldata dungeonMasters,
        bytes calldata encodedHatsStrings,
        bytes calldata sheetsStrings
    ) public returns (address) {
        address clones = create(dao);
        bytes memory encodedHatsAddresses =
            abi.encode(admins, dungeonMasters, address(implementations), address(clones));

        initializeContracts(clones, dao, encodedHatsAddresses, encodedHatsStrings, sheetsStrings);

        return clones;
    }

    function createExperience() public returns (address) {
        if (implementations.experienceImplementation() == address(0)) {
            revert Errors.NotInitialized();
        }

        address experienceClone = address(new ERC1967Proxy(implementations.experienceImplementation(), ""));
        emit ExperienceCreated(experienceClone);
        return experienceClone;
    }

    function createCharacterSheets() public returns (address) {
        if (implementations.characterSheetsImplementation() == address(0)) {
            revert Errors.NotInitialized();
        }

        address characterSheetsClone = address(new ERC1967Proxy(implementations.characterSheetsImplementation(), ""));

        emit CharacterSheetsCreated(characterSheetsClone);

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

        emit ItemsCreated(itemsClone);
        return itemsClone;
    }

    function createClasses() public returns (address) {
        if (implementations.classesImplementation() == address(0)) {
            revert Errors.NotInitialized();
        }
        address classesClone = address(new ERC1967Proxy(implementations.classesImplementation(), ""));
        emit ClassesCreated(classesClone);
        return classesClone;
    }

    function createCharacterEligibilityAdaptorFromDao(address _dao) public returns (address) {
        if (_dao == address(0)) {
            return address(0);
        }
        if (_checkMolochV3Dao(_dao)) {
            return createCharacterEligibilityAdaptor(implementations.molochV3EligibilityAdaptorImplementation());
        }
        if (_checkMolochV2Dao(_dao)) {
            return createCharacterEligibilityAdaptor(implementations.molochV2EligibilityAdaptorImplementation());
        }
        revert Errors.UnsupportedInterface();
    }

    function createCharacterEligibilityAdaptor(address _characterEligibilityAdaptorImplementation)
        public
        returns (address)
    {
        if (
            _characterEligibilityAdaptorImplementation == address(0)
                || !IERC165(_characterEligibilityAdaptorImplementation).supportsInterface(ELIGIBILITY_INTERFACE_ID)
        ) {
            revert Errors.UnsupportedInterface();
        }

        address characterEligibilityAdaptorClone =
            address(new ERC1967Proxy(_characterEligibilityAdaptorImplementation, ""));
        emit CharacterEligibilityAdaptorCreated(characterEligibilityAdaptorClone);
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
        emit ClassLevelAdaptorCreated(classLevelAdaptorClone);
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
     * @notice This will initialize all the contracts with default values.
     * @dev If custom settings are required for contracts (custom eligibility adaptors, level adaptors etc.  please initialize the contracts seperatly)
     * @param dao the address of the dao who's membership will restrict character sheets eligibility.  address(0) for no dao restriction;
     * @param encodedHatsAddresses this will be the hats adaptor initialization data
     *        1. address[] admins the list of addresses that will have admin priviledges
     *        2. address[] gameMasters the list of addresses that will have gameMasterpriviledges
     *        3. address implementations the address of the ImplementationAddressStorage contract
     *        4. address clonesStorage the address of the cloned clones storageContract;
     *
     * @param encodedHatsStrings the encoded strings needed for the hats adaptor init.
     *        1.  string _baseImgUri
     *        2.  string topHatDescription
     *        3.  string adminUri
     *        4.  string adminDescription
     *        5.  string gameMasterUri
     *        6.  string gameMasterDescription
     *        7.  string playerUri
     *        8.  string playerDescription
     *        9.  string characterUri
     *        10. string characterDescription
     *
     * @param sheetsStrings encoded string data strings to include must be in this order:
     *        1. the base metadata uri for the character sheets clone
     *        2. the base character token uri for the character sheets clone
     *        3. the base uri for the ITEMS contract
     *        4. the base uri for the CLASSES contract
     */
    function initializeContracts(
        address clonesStorageAddress,
        address dao,
        bytes memory encodedHatsAddresses,
        bytes calldata encodedHatsStrings,
        bytes calldata sheetsStrings
    ) public {
        IClonesAddressStorage clones = IClonesAddressStorage(clonesStorageAddress);

        if (clones.characterEligibilityAdaptor() != address(0)) {
            ICharacterEligibilityAdaptor(clones.characterEligibilityAdaptor()).initialize(msg.sender, dao);
        }
        ClassLevelAdaptor(clones.classLevelAdaptor()).initialize(clonesStorageAddress);
        HatsAdaptor(clones.hatsAdaptor()).initialize(msg.sender, encodedHatsAddresses, encodedHatsStrings);

        CharacterSheetsImplementation(clones.characterSheets()).initialize(
            _encodeCharacterInitData(clonesStorageAddress, sheetsStrings)
        );

        ItemsImplementation(clones.items()).initialize(_encodeItemsData(clonesStorageAddress, sheetsStrings));

        ClassesImplementation(clones.classes()).initialize(_encodeClassesData(clonesStorageAddress, sheetsStrings));
        ItemsManagerImplementation(clones.itemsManager()).initialize(clonesStorageAddress);
        ExperienceImplementation(clones.experience()).initialize(clonesStorageAddress);

        emit NewGameStarted(msg.sender, clonesStorageAddress, encodedHatsAddresses, encodedHatsStrings);
    }

    function _createSheetsAndItems() private returns (address, address) {
        address characterSheetsClone = createCharacterSheets();
        address itemsClone = createItems();

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

    function _checkMolochV3Dao(address dao) private view returns (bool) {
        if (dao != address(0)) {
            (bool success,) = address(dao).staticcall(abi.encodeWithSelector(bytes4(keccak256("sharesToken()"))));
            return success;
        }
        return false;
    }

    function _checkMolochV2Dao(address dao) private view returns (bool) {
        if (dao != address(0)) {
            (bool success,) =
                address(dao).staticcall(abi.encodeWithSelector(bytes4(keccak256("members(address)")), address(0)));
            return success;
        }
        return false;
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
