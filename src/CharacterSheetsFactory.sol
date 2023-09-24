pragma solidity ^0.8.19;
// SPDX-License-Identifier: MIT

import {OwnableUpgradeable} from "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ERC1967Proxy} from "openzeppelin-contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {CharacterSheetsImplementation} from "./implementations/CharacterSheetsImplementation.sol";
import {ClassesImplementation} from "./implementations/ClassesImplementation.sol";
import {ExperienceImplementation} from "./implementations/ExperienceImplementation.sol";
import {ItemsImplementation} from "./implementations/ItemsImplementation.sol";

// import "forge-std/console2.sol";
contract CharacterSheetsFactory is OwnableUpgradeable {
    address public characterSheetsImplementation;
    address public itemsImplementation;
    address public classesImplementation;
    address public erc6551Registry;
    address public erc6551AccountImplementation;
    address public experienceImplementation;

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

    /**
     * @param dungeonMasters an array of addresses that will have the DUNGEON_MASTER role.
     * @param eligibilityAdaptor the adaptor use to determin the elegibility of an account to roll a character sheet.
     * @param data the encoded strings o the charactersheets, experience and classes base URI's
     * @return the address of the characterSheets clone.
     * @return the address of the experienceAndItems clone.
     * @return the address of the classes clone.
     */

    function create(address[] calldata dungeonMasters, address eligibilityAdaptor, bytes calldata data)
        external
        returns (address, address, address, address)
    {
        require(
            itemsImplementation != address(0) && characterSheetsImplementation != address(0)
                && erc6551AccountImplementation != address(0),
            "update implementation addresses"
        );

        address characterSheetsClone = address(new ERC1967Proxy(characterSheetsImplementation, ""));

        address experienceClone = address(new ERC1967Proxy(experienceImplementation, ""));

        address itemsClone = address(new ERC1967Proxy(itemsImplementation, ""));

        address classesClone = address(new ERC1967Proxy(classesImplementation, ""));

        // avoids stacc too dank
        bytes memory encodedAddresses = abi.encode(
            eligibilityAdaptor, dungeonMasters, characterSheetsClone, experienceClone, itemsClone, classesClone
        );

        _initializeContracts(encodedAddresses, data);

        emit CharacterSheetsCreated(msg.sender, characterSheetsClone, classesClone, itemsClone, experienceClone);

        _nonce++;

        return (characterSheetsClone, itemsClone, experienceClone, classesClone);
    }

    function _initializeContracts(bytes memory encodedAddresses, bytes calldata data) private {
        (
            address eligibilityAdaptor,
            address[] memory dungeonMasters,
            address characterSheetsClone,
            address experienceClone,
            address itemsClone,
            address classesClone
        ) = abi.decode(encodedAddresses, (address, address[], address, address, address, address));

        CharacterSheetsImplementation(characterSheetsClone).initialize(
            _encodeCharacterInitData(
                eligibilityAdaptor, dungeonMasters, itemsClone, experienceClone, classesClone, data
            )
        );

        ItemsImplementation(itemsClone).initialize(_encodeItemsData(characterSheetsClone, data));

        ClassesImplementation(classesClone).initialize(_encodeClassesData(characterSheetsClone, data));

        ExperienceImplementation(experienceClone).initialize(characterSheetsClone);
    }

    function _encodeCharacterInitData(
        address eligibilityAdaptor,
        address[] memory dungeonMasters,
        address itemsClone,
        address experienceClone,
        address classesClone,
        bytes memory data
    ) private view returns (bytes memory) {
        (string memory characterSheetsMetadataUri, string memory characterSheetsBaseUri,,) = _decodeStrings(data);

        bytes memory encodedCharacterSheetParameters = abi.encode(
            eligibilityAdaptor,
            dungeonMasters,
            msg.sender,
            classesClone,
            itemsClone,
            experienceClone,
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

    function _encodeClassesData(address characterSheetsClone, bytes memory data) private pure returns (bytes memory) {
        (,,, string memory classesBaseUri) = _decodeStrings(data);
        return abi.encode(characterSheetsClone, classesBaseUri);
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
