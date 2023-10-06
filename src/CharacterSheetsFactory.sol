pragma solidity ^0.8.19;
// SPDX-License-Identifier: MIT

import {OwnableUpgradeable} from "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ERC1967Proxy} from "openzeppelin-contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {HatsModuleFactory} from "hats-module/HatsModuleFactory.sol";

import {CharacterSheetsImplementation} from "./implementations/CharacterSheetsImplementation.sol";
import {ClassesImplementation} from "./implementations/ClassesImplementation.sol";
import {ExperienceImplementation} from "./implementations/ExperienceImplementation.sol";
import {ItemsImplementation} from "./implementations/ItemsImplementation.sol";
import {EligibilityAdaptor} from "./adaptors/EligibilityAdaptor.sol";
import {ClassLevelAdaptor} from "./adaptors/ClassLevelAdaptor.sol";

import {IERC165} from "openzeppelin-contracts/utils/introspection/IERC165.sol";

import {Errors} from "./lib/Errors.sol";

// import "forge-std/console2.sol";

contract CharacterSheetsFactory is OwnableUpgradeable {
    address public characterSheetsImplementation;
    address public itemsImplementation;
    address public classesImplementation;
    address public erc6551Registry;
    address public erc6551AccountImplementation;
    address public experienceImplementation;
    address public eligibilityAdaptorImplementation;
    address public classLevelAdaptorImplementation;

    //hats addresses
    address public hatsModuleFactory;
    address public characterHatsEligibilityModule;
    address public playerHatsEligibilityModule;
    address public hatsAdaptorImplementation;

    bytes4 public constant ELIGIBILITY_INTERFACE_ID = 0x671ccc5a;
    bytes4 public constant CLASS_LEVELS_INTERFACE_ID = 0xfe211eb1;

    uint256 private _nonce;

    event CharacterSheetsCreated(
        address creator, address characterSheets, address classes, address items, address experience
    );
    event CharacterSheetsUpdated(address newCharacterSheets);
    event ExperienceUpdated(address newExperience);
    event ItemsUpdated(address newItems);
    event RegistryUpdated(address newRegistry);
    event ERC6551AccountImplementationUpdated(address newImplementation);
    event ClassesImplementationUpdated(address newClasses);
    event EligibilityAdaptorUpdated(address newAdaptor);
    event ClassLevelAdaptorUpdated(address newAdaptor);
    event HatsAdaptorUpdated(address newHatsAdaptor);

    function initialize() external initializer {
        __Context_init_unchained();
        __Ownable_init_unchained();
    }

    function updateCharacterSheetsImplementation(address _sheetImplementation) external onlyOwner {
        characterSheetsImplementation = _sheetImplementation;
        emit CharacterSheetsUpdated(_sheetImplementation);
    }

    function updateItemsImplementation(address _itemsImplementation) external onlyOwner {
        itemsImplementation = _itemsImplementation;
        emit ItemsUpdated(_itemsImplementation);
    }

    function updateExperienceImplementation(address _experienceImplementation) external onlyOwner {
        experienceImplementation = _experienceImplementation;
        emit ExperienceUpdated(_experienceImplementation);
    }

    function updateERC6551Registry(address _newRegistry) external onlyOwner {
        erc6551Registry = _newRegistry;
        emit RegistryUpdated(erc6551Registry);
    }

    function updateERC6551AccountImplementation(address _newImplementation) external onlyOwner {
        erc6551AccountImplementation = _newImplementation;
        emit ERC6551AccountImplementationUpdated(_newImplementation);
    }

    function updateClassesImplementation(address _newClasses) external onlyOwner {
        classesImplementation = _newClasses;
        emit ClassesImplementationUpdated(classesImplementation);
    }

    function updateEligibilityAdaptorImplementation(address _newEligibilityAdaptor) external onlyOwner {
        eligibilityAdaptorImplementation = _newEligibilityAdaptor;
        emit EligibilityAdaptorUpdated(_newEligibilityAdaptor);
    }

    function updateClassLevelAdaptorImplementation(address _newClassLevelAdaptor) external onlyOwner {
        classLevelAdaptorImplementation = _newClassLevelAdaptor;
        emit ClassLevelAdaptorUpdated(_newClassLevelAdaptor);
    }

    function updateHatsAdaptorImplementation(address _newHatsAdaptor) external onlyOwner {
        hatsAdaptorImplementation = _newHatsAdaptor;

        emit HatsAdaptorUpdated(_newHatsAdaptor);
    }

    /// create functions must be called first before the initialize call is made

    /**
     * @dev create function for all contracts and adaptors
     *     @param dungeonMasters an array of all addresses with dungeonMasterPermissions
     *     @param dao the address of a dao to be used with the character sheets elegibility adaptor pass in address(0) to have no elegibilty limitations
     *     @param _classLevelAdaptorImplementation the class Level adaptor address to be used.  pass in address(0) to use the default adaptor with D&D style leveling requirements
     *     @param data the encoded bytes of the correct initilization data see init function notes for correct data to be encoded
     */
    function create(
        address[] calldata dungeonMasters,
        address dao,
        address _classLevelAdaptorImplementation,
        bytes calldata data
    ) external returns (address, address, address, address) {
        (address characterSheetsClone, address itemsClone) = _createSheetsAndItems(dungeonMasters, dao, data);

        (address classesClone, address experienceClone) =
            _createClassesAndExperience(characterSheetsClone, _classLevelAdaptorImplementation, data);

        emit CharacterSheetsCreated(msg.sender, characterSheetsClone, classesClone, itemsClone, experienceClone);

        return (characterSheetsClone, classesClone, itemsClone, experienceClone);
    }

    function createExperience() public returns (address) {
        if (experienceImplementation == address(0)) {
            revert Errors.NotInitialized();
        }

        address experienceClone = address(new ERC1967Proxy(experienceImplementation, ""));

        return experienceClone;
    }

    function createCharacterSheets() public returns (address) {
        if (characterSheetsImplementation == address(0)) {
            revert Errors.NotInitialized();
        }

        address characterSheetsClone = address(new ERC1967Proxy(characterSheetsImplementation, ""));

        return characterSheetsClone;
    }

    function createItems() public returns (address) {
        if (itemsImplementation == address(0)) {
            revert Errors.NotInitialized();
        }
        address itemsClone = address(new ERC1967Proxy(itemsImplementation, ""));
        return itemsClone;
    }

    function createClasses() public returns (address) {
        if (classesImplementation == address(0)) {
            revert Errors.NotInitialized();
        }
        address classesClone = address(new ERC1967Proxy(classesImplementation, ""));
        return classesClone;
    }

    function createEligibilityAdaptor() public returns (address) {
        if (eligibilityAdaptorImplementation == address(0)) {
            revert Errors.NotInitialized();
        }

        return createEligibilityAdaptor(eligibilityAdaptorImplementation);
    }

    function createEligibilityAdaptor(address _eligibilityAdaptorImplementation) public returns (address) {
        if (!IERC165(_eligibilityAdaptorImplementation).supportsInterface(ELIGIBILITY_INTERFACE_ID)) {
            revert Errors.UnsupportedInterface();
        }

        address eligibilityAdaptorClone = address(new ERC1967Proxy(_eligibilityAdaptorImplementation, ""));
        return eligibilityAdaptorClone;
    }

    function createClassLevelAdaptor() public returns (address) {
        if (classLevelAdaptorImplementation == address(0)) {
            revert Errors.NotInitialized();
        }

        return createClassLevelAdaptor(classLevelAdaptorImplementation);
    }

    function createClassLevelAdaptor(address _classLevelAdaptorImplementation) public returns (address) {
        if (!IERC165(_classLevelAdaptorImplementation).supportsInterface(CLASS_LEVELS_INTERFACE_ID)) {
            revert Errors.UnsupportedInterface();
        }

        address classLevelAdaptorClone = address(new ERC1967Proxy(_classLevelAdaptorImplementation, ""));
        return classLevelAdaptorClone;
    }

    function createHatsAdaptor() public returns (address) {
        if (hatsAdaptorImplementation == address(0)) {
            revert Errors.VariableNotSet();
        }

        return createHatsAdaptor(hatsAdaptorImplementation);
    }

    function createHatsAdaptor(address _hatsAdaptorImplementation) public returns (address) {
        address hatsAdaptor = address(new ERC1967Proxy(_hatsAdaptorImplementation, ""));
        return hatsAdaptor;
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
    function initializeContracts(bytes calldata encodedAddresses, bytes calldata data) public {
        (
            address eligibilityAdaptorClone,
            address classLevelAdaptorClone,
            address[] memory dungeonMasters,
            address characterSheetsClone,
            address experienceClone,
            address itemsClone,
            address classesClone
        ) = abi.decode(encodedAddresses, (address, address, address[], address, address, address, address));

        //stacc too dank
        bytes memory encodedCharInitAddresses = abi.encode(eligibilityAdaptorClone, dungeonMasters, itemsClone);

        CharacterSheetsImplementation(characterSheetsClone).initialize(
            _encodeCharacterInitData(encodedCharInitAddresses, data)
        );

        ItemsImplementation(itemsClone).initialize(_encodeItemsData(characterSheetsClone, data));

        ClassesImplementation(classesClone).initialize(
            _encodeClassesData(characterSheetsClone, experienceClone, classLevelAdaptorClone, data)
        );

        ExperienceImplementation(experienceClone).initialize(_encodeExpData(characterSheetsClone, classesClone));
    }

    function _createSheetsAndItems(address[] calldata dungeonMasters, address dao, bytes calldata data)
        private
        returns (address, address)
    {
        address characterSheetsClone = createCharacterSheets();
        address itemsClone = createItems();

        address eligibilityAdaptorClone = dao != address(0) ? createEligibilityAdaptor() : address(0);

        bytes memory encodedCharInitAddresses = abi.encode(eligibilityAdaptorClone, dungeonMasters, itemsClone);

        CharacterSheetsImplementation(characterSheetsClone).initialize(
            _encodeCharacterInitData(encodedCharInitAddresses, data)
        );

        if (dao != address(0)) {
            EligibilityAdaptor(eligibilityAdaptorClone).initialize(msg.sender, dao);
        }

        return (characterSheetsClone, itemsClone);
    }

    function _createClassesAndExperience(
        address characterSheetsClone,
        address _classLevelAdaptorImplementation,
        bytes calldata data
    ) private returns (address, address) {
        address experienceClone = createExperience();
        address classesClone = createClasses();
        address classLevelAdaptorClone = _classLevelAdaptorImplementation == address(0)
            ? createClassLevelAdaptor()
            : createClassLevelAdaptor(_classLevelAdaptorImplementation);

        ClassesImplementation(classesClone).initialize(
            _encodeClassesData(characterSheetsClone, experienceClone, classLevelAdaptorClone, data)
        );

        ExperienceImplementation(experienceClone).initialize(_encodeExpData(characterSheetsClone, classesClone));

        ClassLevelAdaptor(classLevelAdaptorClone).initialize(msg.sender, classesClone, experienceClone);

        return (classesClone, experienceClone);
    }

    function _encodeCharacterInitData(bytes memory encodedInitData, bytes memory data)
        private
        view
        returns (bytes memory)
    {
        (string memory characterSheetsMetadataUri, string memory characterSheetsBaseUri,,) = _decodeStrings(data);

        (address eligibilityAdaptorClone, address[] memory dungeonMasters, address itemsClone) =
            abi.decode(encodedInitData, (address, address[], address));

        bytes memory encodedCharacterSheetParameters = abi.encode(
            eligibilityAdaptorClone,
            dungeonMasters,
            msg.sender,
            itemsClone,
            erc6551Registry,
            erc6551AccountImplementation,
            characterSheetsMetadataUri,
            characterSheetsBaseUri
        );

        return (encodedCharacterSheetParameters);
    }

    function _encodeItemsData(address characterSheetsClone, bytes memory data) private pure returns (bytes memory) {
        (,, string memory itemsBaseUri,) = _decodeStrings(data);

        return abi.encode(characterSheetsClone, itemsBaseUri);
    }

    function _encodeClassesData(
        address characterSheetsClone,
        address experienceClone,
        address classLevelAdaptorClone,
        bytes memory data
    ) private pure returns (bytes memory) {
        (,,, string memory classesBaseUri) = _decodeStrings(data);
        return abi.encode(characterSheetsClone, experienceClone, classLevelAdaptorClone, classesBaseUri);
    }

    function _encodeExpData(address characterSheetsClone, address classesClone) private pure returns (bytes memory) {
        return abi.encode(characterSheetsClone, classesClone);
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
