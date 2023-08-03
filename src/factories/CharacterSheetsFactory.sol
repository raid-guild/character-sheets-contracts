pragma solidity ^0.8.0;
// SPDX-License-Identifier: MIT

import "../implementations/CharacterSheetsImplementation.sol";
import "@openzeppelin/contracts-upgradeable/proxy/ClonesUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract CharacterSheetsFactory is OwnableUpgradeable {
    address characterSheetsImplementation;
    address experienceAndItemsImplementation;
    address hatsAddress;

    address[] public CharacterSheetss;

    event CharacterSheetsCreated(address newCharacterSheets, address creator);
    event CharacterSheetsUpdated(address newCharacterSheets);
    event ExperienceUpdated(address newExperience);
    event ExperienceAndItemsCreated(address newExp, address creator);

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

    function updateHats(address _hats)external onlyOwner{
        hatsAddress = _hats;
    }

    function create(
        address[] calldata dungeonMasters,
        address dao,
        string calldata experienceBaseuri,
        string calldata characterSheetsBaseUri
    ) external returns (address, address) {
        require(
            experienceAndItemsImplementation != address(0) && characterSheetsImplementation != address(0),
            "must update implementation addresses"
        );

        address characterSheetsClone = ClonesUpgradeable.cloneDeterministic(characterSheetsImplementation, 0);
        address experienceClone = ClonesUpgradeable.cloneDeterministic(experienceAndItemsImplementation, 0);

        bytes memory encodedCharacterSheetParameters =
            abi.encode(dao, dungeonMasters, experienceClone, characterSheetsBaseUri);
        bytes memory encodedExperienceParameters =
            abi.encode(dao, dungeonMasters, characterSheetsClone, hatsAddress, experienceBaseuri);

        CharacterSheetsImplementation(characterSheetsClone).initialize(encodedCharacterSheetParameters);
        ExperienceAndItemsImplementation(experienceClone).initialize(encodedExperienceParameters);

        emit CharacterSheetsCreated(characterSheetsClone, msg.sender);
        emit ExperienceAndItemsCreated(experienceClone, msg.sender);

        return (characterSheetsClone, experienceClone);
    }
}
