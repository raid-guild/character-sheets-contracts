pragma solidity ^0.8.0;
// SPDX-License-Identifier: MIT

import "../implementations/CharacterSheetsImplementation.sol";
import "@openzeppelin/contracts-upgradeable/proxy/ClonesUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract CharacterSheetsFactory is OwnableUpgradeable {
    address public characterSheetsImplementation;
    address public experienceAndItemsImplementation;
    address public hatsAddress;
    address public erc6551Registry;
    address public erc6551AccountImplementation;

    address[] public CharacterSheetss;

    event CharacterSheetsCreated(address newCharacterSheets, address creator);
    event CharacterSheetsUpdated(address newCharacterSheets);
    event ExperienceUpdated(address newExperience);
    event ExperienceAndItemsCreated(address newExp, address creator);
    event RegistryUpdated(address newRegistry);
    event ERC6551AccountImplementationUpdated(address newImplementation);
    event HatsUpdated(address newHats);

    uint256 private nonce;

    function initialize() external initializer {
        __Context_init_unchained();
        __Ownable_init_unchained();
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

    function updaterERC6551AccountImplementation(address _newImplementation) external onlyOwner {
        erc6551AccountImplementation = _newImplementation;
        emit ERC6551AccountImplementationUpdated(_newImplementation);
    }

    function updateHats(address _hats) external onlyOwner {
        hatsAddress = _hats;
        emit HatsUpdated(hatsAddress);
    }
    /**
     *
     * @param dungeonMasters an array of addresses that will have the DUNGEON_MASTER role.
     * @param dao the dao who's member list will be able to mint character sheets.
     * @param default_admin the default admin of the characterSheets.
     * @param experienceBaseuri the base uri for the experience and items erc1155 contract.
     * @param characterSheetsBaseUri the base uri for the characterSheets erc721 contract.
     * @return the address of the characterSheets clone.
     * @return the address of the experienceAndItems clone.
     */

    function create(
        address[] calldata dungeonMasters,
        address dao,
        address default_admin,
        string calldata experienceBaseuri,
        string calldata characterSheetsBaseUri
    ) external returns (address, address) {
        require(
            experienceAndItemsImplementation != address(0) && characterSheetsImplementation != address(0)
                && erc6551AccountImplementation != address(0),
            "must update implementation addresses"
        );

        address characterSheetsClone =
            ClonesUpgradeable.cloneDeterministic(characterSheetsImplementation, keccak256(abi.encode(nonce)));

        address experienceClone =
            ClonesUpgradeable.cloneDeterministic(experienceAndItemsImplementation, keccak256(abi.encode(nonce)));

        bytes memory encodedCharacterSheetParameters = abi.encode(
            dao,
            dungeonMasters,
            default_admin,
            experienceClone,
            erc6551Registry,
            erc6551AccountImplementation,
            characterSheetsBaseUri
        );

        bytes memory encodedExperienceParameters =
            abi.encode(dao, default_admin, characterSheetsClone, hatsAddress, experienceBaseuri);

        CharacterSheetsImplementation(characterSheetsClone).initialize(encodedCharacterSheetParameters);

        ExperienceAndItemsImplementation(experienceClone).initialize(encodedExperienceParameters);

        emit CharacterSheetsCreated(characterSheetsClone, msg.sender);
        emit ExperienceAndItemsCreated(experienceClone, msg.sender);
        nonce++;
        return (characterSheetsClone, experienceClone);
    }
}
