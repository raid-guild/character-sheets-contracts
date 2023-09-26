pragma solidity ^0.8.19;
// SPDX-License-Identifier: MIT

import {OwnableUpgradeable} from "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ERC1967Proxy} from "openzeppelin-contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {CharacterSheetsImplementation} from "./implementations/CharacterSheetsImplementation.sol";
import {ClassesImplementation} from "./implementations/ClassesImplementation.sol";
import {ExperienceImplementation} from "./implementations/ExperienceImplementation.sol";
import {ItemsImplementation} from "./implementations/ItemsImplementation.sol";
import {EligibilityAdaptor} from "./adaptors/EligibilityAdaptor.sol";
import {ClassLevelAdaptor} from "./adaptors/ClassLevelAdaptor.sol";
import {Errors} from "./lib/Errors.sol";

// import "forge-std/console2.sol";

contract CharacterSheetsFactory is OwnableUpgradeable {
    address public characterSheetsImplementation;
    address public itemsImplementation;
    address public classesImplementation;
    address public erc6551Registry;
    address public erc6551AccountImplementation;
    address public experienceImplementation;

    bytes4 public constant ELIGIBILITY_INTERFACE_ID = 0x671ccc5a;
    bytes4 public constant CLASS_LEVELS_INTERFACE_ID = 0xfe211eb1;

    uint256 private _nonce;

    event CharacterSheetsCreated(
        address creator, address characterSheets, address classes, address items, address experienceAndItems
    );
    event CharacterSheetsUpdated(address newCharacterSheets);
    event ExperienceUpdated(address newExperience);
    event ItemsUpdated(address newItems);
    event RegistryUpdated(address newRegistry);
    event ERC6551AccountImplementationUpdated(address newImplementation);
    event ClassesImplementationUpdated(address newClasses);

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

    /// create functions

    function createExperience() public returns (address) {
        require(experienceImplementation != address(0), "update experience implementation");

        address experienceClone = address(new ERC1967Proxy(experienceImplementation, ""));

        return experienceClone;
    }

    function createCharacterSheets() public returns (address) {
        require(characterSheetsImplementation != address(0), "update character sheets address");

        address characterSheetsClone = address(new ERC1967Proxy(characterSheetsImplementation, ""));

        return characterSheetsClone;
    }

    function createItems() public returns (address) {
        address itemsClone = address(new ERC1967Proxy(itemsImplementation, ""));
        return itemsClone;
    }

    function createClasses() public returns (address) {
        address classesClone = address(new ERC1967Proxy(classesImplementation, ""));
        return classesClone;
    }

    function createEligibilityAdaptor(address eligibilityAdaptorImplementation) public returns (address) {
        require(
            EligibilityAdaptor(eligibilityAdaptorImplementation).supportsInterface(ELIGIBILITY_INTERFACE_ID),
            "invalid interface"
        );

        address eligibilityAdaptorClone = address(new ERC1967Proxy(eligibilityAdaptorImplementation, ""));
        return eligibilityAdaptorClone;
    }

    function createClassLevelAdaptor(address classLevelAdaptorImplementation) public returns (address) {
        require(
            ClassLevelAdaptor(classLevelAdaptorImplementation).supportsInterface(CLASS_LEVELS_INTERFACE_ID),
            "invalid interface"
        );

        address classLevelAdaptorClone = address(new ERC1967Proxy(classLevelAdaptorImplementation, ""));
        return classLevelAdaptorClone;
    }

    // adaptors must be initialized seperately

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

        //stacc too dank again
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
