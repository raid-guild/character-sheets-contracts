pragma solidity ^0.8.0;
// SPDX-License-Identifier: MIT
import "./CharacterSheetsImplementation.sol";
import "@openzeppelin/contracts-upgradeable/proxy/ClonesUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";


contract CharacterSheetsFactory is OwnableUpgradeable {
    address characterSheetsImplementation;

    address[] public CharacterSheetss;

    event CharacterSheetsCreated(address newCharacterSheets, address  _creator);
    event CharacterSheetsUpdated(address newCharacterSheets);

  function initialize() external initializer {
    __Context_init();
    __Ownable_init();
  }
    function updateCharacterSheetsImplementation(address _sheetImplementation) external onlyOwner {
        characterSheetsImplementation = _sheetImplementation;
        emit CharacterSheetsUpdated(_sheetImplementation);
    }

    function create(bytes calldata _encodedParameters, address ownedBy) external returns (address) {
        address clone = ClonesUpgradeable.clone(characterSheetsImplementation);

        emit CharacterSheetsCreated(clone, ownedBy);
        
        CharacterSheetsImplementation(clone).initialize(_encodedParameters);
        
        return clone;
    }
}