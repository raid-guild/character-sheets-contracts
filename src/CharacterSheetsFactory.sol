pragma solidity ^0.8.19;
// SPDX-License-Identifier: MIT

import {CharacterSheetsImplementation} from "./implementations/CharacterSheetsImplementation.sol";
import {ClassesImplementation} from "./implementations/ClassesImplementation.sol";
import {ClonesUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/proxy/ClonesUpgradeable.sol";
import {OwnableUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import {ExperienceAndItemsImplementation} from "./implementations/ExperienceAndItemsImplementation.sol";

// import "forge-std/console2.sol";
contract CharacterSheetsFactory is OwnableUpgradeable {
    address public characterSheetsImplementation;
    address public experienceAndItemsImplementation;
    address public classesImplementation;
    address public erc6551Registry;
    address public erc6551AccountImplementation;

    uint256 private _nonce;

    event CharacterSheetsCreated(address creator, address characterSheets, address classes, address experienceAndItems);
    event CharacterSheetsUpdated(address newCharacterSheets);
    event ExperienceUpdated(address newExperience);
    event RegistryUpdated(address newRegistry);
    event ERC6551AccountImplementationUpdated(address newImplementation);
    event ClassesImplementationUpdated(address newClasses);

    function initialize() external initializer {
        __Context_init_unchained();
        __Ownable_init_unchained(msg.sender);
    }

    function updateCharacterSheetsImplementation(address _sheetImplementation) external onlyOwner {
        characterSheetsImplementation = _sheetImplementation;
        emit CharacterSheetsUpdated(_sheetImplementation);
    }

    function updateExperienceAndItemsImplementation(address _experienceImplementation) external onlyOwner {
        experienceAndItemsImplementation = _experienceImplementation;
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
     * @param dao the dao who"s member list will be able to mint character sheets.
     * @param data the encoded strings o the charactersheets, experience and classes base URI's
     * @return the address of the characterSheets clone.
     * @return the address of the experienceAndItems clone.
     * @return the address of the classes clone.
     */

    function create(address[] calldata dungeonMasters, address dao, bytes calldata data)
        external
        returns (address, address, address)
    {
        require(
            experienceAndItemsImplementation != address(0) && characterSheetsImplementation != address(0)
                && erc6551AccountImplementation != address(0),
            "update implementation addresses"
        );

        address characterSheetsClone =
            ClonesUpgradeable.cloneDeterministic(characterSheetsImplementation, keccak256(abi.encode(_nonce)));

        address experienceClone =
            ClonesUpgradeable.cloneDeterministic(experienceAndItemsImplementation, keccak256(abi.encode(_nonce)));

        address classesClone =
            ClonesUpgradeable.cloneDeterministic(classesImplementation, keccak256(abi.encode(_nonce)));

        CharacterSheetsImplementation(characterSheetsClone).initialize(
            _encodeCharacterInitData(dao, dungeonMasters, experienceClone, classesClone, data)
        );

        ExperienceAndItemsImplementation(experienceClone).initialize(
            _encodeExpData(characterSheetsClone, classesClone, data)
        );

        ClassesImplementation(classesClone).initialize(_encodeClassesData(characterSheetsClone, data));

        emit CharacterSheetsCreated(msg.sender, characterSheetsClone, classesClone, experienceClone);

        _nonce++;

        return (characterSheetsClone, experienceClone, classesClone);
    }

    function _initializeContracts(
        address characterSheetsClone,
        address experienceClone,
        address classesClone,
        bytes memory encodedCharacterSheetsParams,
        bytes memory encodedExpParams,
        bytes memory encodedClassesParams
    ) private {
        CharacterSheetsImplementation(characterSheetsClone).initialize(encodedCharacterSheetsParams);

        ExperienceAndItemsImplementation(experienceClone).initialize(encodedExpParams);

        ClassesImplementation(classesClone).initialize(encodedClassesParams);
    }

    function _encodeCharacterInitData(
        address dao,
        address[] memory dungeonMasters,
        address experienceClone,
        address classesClone,
        bytes memory data
    ) private view returns (bytes memory) {
        (string memory characterSheetsMetadataUri, string memory characterSheetsBaseUri,,) = _decodeStrings(data);

        bytes memory encodedCharacterSheetParameters = abi.encode(
            dao,
            dungeonMasters,
            msg.sender,
            classesClone,
            experienceClone,
            erc6551Registry,
            erc6551AccountImplementation,
            characterSheetsMetadataUri,
            characterSheetsBaseUri
        );

        return (encodedCharacterSheetParameters);
    }

    function _encodeExpData(address characterSheetsClone, address classesClone, bytes memory data)
        private
        pure
        returns (bytes memory)
    {
        (,, string memory experienceBaseUri,) = _decodeStrings(data);

        return abi.encode(characterSheetsClone, classesClone, experienceBaseUri);
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
