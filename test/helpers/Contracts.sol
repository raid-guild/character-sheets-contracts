// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
pragma abicoder v2;

// import "forge-std/Test.sol";
// import "forge-std/console2.sol";
// import {ItemsImplementation} from "../../src/implementations/ItemsImplementation.sol";
// import {ExperienceImplementation} from "../../src/implementations/ExperienceImplementation.sol";
// import {CharacterSheetsFactory} from "../../src/CharacterSheetsFactory.sol";
// import {CharacterEligibilityAdaptor} from "../../src/adaptors/CharacterEligibilityAdaptor.sol";
// import {ClassLevelAdaptor} from "../../src/adaptors/ClassLevelAdaptor.sol";
// import {CharacterSheetsImplementation} from "../../src/implementations/CharacterSheetsImplementation.sol";
// import {ClassesImplementation} from "../../src/implementations/ClassesImplementation.sol";
// import {IMolochDAO} from "../../src/interfaces/IMolochDAO.sol";
// import {Moloch} from "../../src/mocks/MockMoloch.sol";

// import "../../src/lib/Structs.sol";
// import "murky/src/Merkle.sol";
// import {ERC6551Registry} from "../../src/mocks/ERC6551Registry.sol";
// import {CharacterAccount} from "../../src/CharacterAccount.sol";
// import {MultiSend} from "../../src/lib/MultiSend.sol";
// import {Category} from "../../src/lib/MultiToken.sol";

// // hats imports
// import {HatsAdaptor} from "../../src/adaptors/HatsAdaptor.sol";
// import {HatsModuleFactory} from "hats-module/HatsModuleFactory.sol";
// import {Hats} from "hats-protocol/Hats.sol";
// import {AdminHatEligibilityModule} from "../../src/adaptors/hats-modules/AdminHatEligibilityModule.sol";
// import {DungeonMasterHatEligibilityModule} from "../../src/adaptors/hats-modules/DungeonMasterHatEligibilityModule.sol";
// import {PlayerHatEligibilityModule} from "../../src/adaptors/hats-modules/PlayerHatEligibilityModule.sol";
// import {CharacterHatEligibilityModule} from "../../src/adaptors/hats-modules/CharacterHatEligibilityModule.sol";
// import {ItemsManagerImplementation} from "../../src/implementations/ItemsManagerImplementation.sol";

// import {ImplementationAddressStorage} from "../../src/lib/ImplementationAddressStorage.sol";
// import {ClonesAddressStorage} from "../../src/lib/ClonesAddressStorage.sol";

// import {SetUp, ContractsStruct} from "./SetUp.sol";

// struct HatsContracts {
//     HatsModuleFactory hatsModuleFactory;
//     Hats hats;
// }

// contract Contracts {
//     using stdJson for string;

//     CharacterSheetsImplementation public characterSheets;
//     ExperienceImplementation public experience;
//     ItemsImplementation public items;
//     ItemsManagerImplementation public itemsManager;
//     ClassesImplementation public classes;
//     ClonesAddressStorage public clones;

//     ImplementationAddressStorage public implementationsStorage;
//     CharacterSheetsFactory public characterSheetsFactory;

//     CharacterEligibilityAdaptor public eligibility;
//     ClassLevelAdaptor public classLevels;
//     HatsAdaptor public hatsAdaptor;

//     Moloch public dao;
//     Merkle public merkle;

//     function setConatracts(ContractsStruct memory newContracts) public {
//         characterSheets = newContracts.characterSheets;
//         experience = newContracts.experience;
//         items = newContracts.items;
//         classes = newContracts.classes;

//         characterSheetsFactory = newContracts.characterSheetsFactory;
//         eligibility = newContracts.eligibility;
//         classLevels = newContracts.classLevels;
//         hatsAdaptor = newContracts.hatsAdaptor;
//         hatsModuleFactory = newContracts.hatsModuleFactory;
//         hats = newContracts.hats;
//         itemsManager = newContracts.itemsManager;
//         clones = newContracts.clones;
//         implementationsStorage = newContracts.implementationsStorage;
//         dao = newContracts.dao;
//         merkle = newContracts.merkle;
//     }
// }
