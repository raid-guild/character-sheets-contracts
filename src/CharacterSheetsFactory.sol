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
// import "forge-std/console2.sol";

contract CharacterSheetsFactory is OwnableUpgradeable {
    address public characterSheetsImplementation;
    address public itemsImplementation;
    address public classesImplementation;
    address public erc6551Registry;
    address public erc6551AccountImplementation;
    address public experienceImplementation;

    bytes4 public constant ELIGIBILITY_INTERFACE_ID = 0x671ccc5a;

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
        //require interface id

        address classLevelAdaptorClone = address(new ERC1967Proxy(classLevelAdaptorImplementation, ""));
        return classLevelAdaptorClone;
    }

    // /**
    //  * @param dungeonMasters an array of addresses that will have the DUNGEON_MASTER role.
    //  * @param eligibilityAdaptorImplementation the adaptor use to determin the elegibility of an account to roll a character sheet.
    //  * @param classLevelAdaptorImplementation is the adaptor to be used for the class leveling schema
    //  * @param data the encoded strings o the charactersheets, experience and classes base URI's
    //  * @return the address of the characterSheets clone.
    //  * @return the address of the experienceAndItems clone.
    //  * @return the address of the classes clone.
    //  */

    // function create(
    //     bytes calldata dungeonMasters,
    //     address eligibilityAdaptorImplementation,
    //     address classLevelAdaptorImplementation,
    //     bytes calldata data
    // ) external returns (address, address, address, address, address, address) {
    //     require(
    //         itemsImplementation != address(0) && characterSheetsImplementation != address(0)
    //             && erc6551AccountImplementation != address(0),
    //         "update implementation addresses"
    //     );

    //     address experienceClone = address(new ERC1967Proxy(experienceImplementation, ""));

    //     address itemsClone = address(new ERC1967Proxy(itemsImplementation, ""));

    //     address classesClone = address(new ERC1967Proxy(classesImplementation, ""));

    //     address eligibilityAdaptorClone = address(new ERC1967Proxy(eligibilityAdaptorImplementation, ""));

    //     address classLevelAdaptorClone = address(new ERC1967Proxy(classLevelAdaptorImplementation, ""));

    //     bytes memory encodedAddresses;
    //     {
    //         // avoids stacc too dank
    //         encodedAddresses = abi.encode(
    //             eligibilityAdaptorClone,
    //             classLevelAdaptorClone,
    //             dungeonMasters,
    //             characterSheetsClone,
    //             experienceClone,
    //             itemsClone,
    //             classesClone
    //         );
    //     }

    //     // this does not initialize the adaptors.  adaptors should be initialized by the deployer.
    //     _initializeContracts(encodedAddresses, data);

    //     emit CharacterSheetsCreated(msg.sender, characterSheetsClone, classesClone, itemsClone, experienceClone);

    //     _nonce++;

    //     return (
    //         characterSheetsClone,
    //         itemsClone,
    //         experienceClone,
    //         classesClone,
    //         eligibilityAdaptorClone,
    //         classLevelAdaptorClone
    //     );
    // }

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

        bytes memory encodedCharInitAddresses =
            abi.encode(eligibilityAdaptorClone, dungeonMasters, itemsClone, experienceClone, classesClone);

        CharacterSheetsImplementation(characterSheetsClone).initialize(
            _encodeCharacterInitData(encodedCharInitAddresses, data)
        );
        ItemsImplementation(itemsClone).initialize(
            _encodeItemsData(characterSheetsClone, classesClone, experienceClone, data)
        );

        ClassesImplementation(classesClone).initialize(
            _encodeClassesData(characterSheetsClone, classLevelAdaptorClone, data)
        );

        ExperienceImplementation(experienceClone).initialize(_encodeExpData(characterSheetsClone, itemsClone));
    }

    function _encodeCharacterInitData(bytes memory encodedInitData, bytes memory data)
        private
        view
        returns (bytes memory)
    {
        (string memory characterSheetsMetadataUri, string memory characterSheetsBaseUri,,) = _decodeStrings(data);

        (
            address eligibilityAdaptorClone,
            address[] memory dungeonMasters,
            address itemsClone,
            address experienceClone,
            address classesClone
        ) = abi.decode(encodedInitData, (address, address[], address, address, address));

        bytes memory encodedCharacterSheetParameters = abi.encode(
            eligibilityAdaptorClone,
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

    function _encodeItemsData(
        address characterSheetsClone,
        address classesClone,
        address experienceClone,
        bytes memory data
    ) private pure returns (bytes memory) {
        (,, string memory itemsBaseUri,) = _decodeStrings(data);

        return abi.encode(characterSheetsClone, classesClone, experienceClone, itemsBaseUri);
    }

    function _encodeClassesData(address characterSheetsClone, address classLevelAdaptorClone, bytes memory data)
        private
        pure
        returns (bytes memory)
    {
        (,,, string memory classesBaseUri) = _decodeStrings(data);
        return abi.encode(characterSheetsClone, classLevelAdaptorClone, classesBaseUri);
    }

    function _encodeExpData(address characterSheetsClone, address itemsClone) private pure returns (bytes memory) {
        return abi.encode(characterSheetsClone, itemsClone);
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
