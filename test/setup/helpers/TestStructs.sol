// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
pragma abicoder v2;

//fatory
import {CharacterSheetsFactory} from "../../../src/CharacterSheetsFactory.sol";
// implementations
import {CharacterSheetsImplementation} from "../../../src/implementations/CharacterSheetsImplementation.sol";
import {ItemsImplementation} from "../../../src/implementations/ItemsImplementation.sol";
import {ItemsManagerImplementation} from "../../../src/implementations/ItemsManagerImplementation.sol";
import {ClassesImplementation} from "../../../src/implementations/ClassesImplementation.sol";
import {ExperienceImplementation} from "../../../src/implementations/ExperienceImplementation.sol";

//address storage
import {ImplementationAddressStorage} from "../../../src/ImplementationAddressStorage.sol";
import {ClonesAddressStorageImplementation} from "../../../src/implementations/ClonesAddressStorageImplementation.sol";

//adaptors
import {CharacterEligibilityAdaptorV2} from "../../../src/adaptors/CharacterEligibilityAdaptorV2.sol";
import {CharacterEligibilityAdaptorV3} from "../../../src/adaptors/CharacterEligibilityAdaptorV3.sol";
import {ICharacterEligibilityAdaptor} from "../../../src/interfaces/ICharacterEligibilityAdaptor.sol";
import {ClassLevelAdaptor} from "../../../src/adaptors/ClassLevelAdaptor.sol";
import {HatsAdaptor} from "../../../src/adaptors/HatsAdaptor.sol";

//erc6551
import {ERC6551Registry} from "../../../src/mocks/ERC6551Registry.sol";
import {CharacterAccount} from "../../../src/CharacterAccount.sol";

// multi Send
import {MultiSend} from "../../../src/lib/MultiSend.sol";
import {Category} from "../../../src/lib/MultiToken.sol";

// hats imports
import {HatsModuleFactory} from "hats-module/HatsModuleFactory.sol";
import {Hats} from "hats-protocol/Hats.sol";

// hats eligibility modules
import {AdminHatEligibilityModule} from "../../../src/adaptors/hats-modules/AdminHatEligibilityModule.sol";
import {GameMasterHatEligibilityModule} from "../../../src/adaptors/hats-modules/GameMasterHatEligibilityModule.sol";
import {PlayerHatEligibilityModule} from "../../../src/adaptors/hats-modules/PlayerHatEligibilityModule.sol";
import {CharacterHatEligibilityModule} from "../../../src/adaptors/hats-modules/CharacterHatEligibilityModule.sol";

//test and mocks
import {IMolochDAOV2} from "../../../src/interfaces/IMolochDAOV2.sol";
import {IMolochDAOV3} from "../../../src/interfaces/IMolochDAOV3.sol";
import {Moloch} from "../../../src/mocks/MockMoloch.sol";

import "murky/src/Merkle.sol";

interface TestStructs {
    struct DeployedContracts {
        CharacterSheetsImplementation characterSheets;
        ExperienceImplementation experience;
        ItemsImplementation items;
        ItemsManagerImplementation itemsManager;
        ClassesImplementation classes;
        ClonesAddressStorageImplementation clones;
        ICharacterEligibilityAdaptor characterEligibility;
        ClassLevelAdaptor classLevels;
        HatsAdaptor hatsAdaptor;
    }

    struct SheetsData {
        uint256 characterId1;
        uint256 characterId2;
    }

    struct ClassesData {
        uint256 classId;
        uint256 classIdClaimable;
    }

    struct ItemsData {
        uint256 itemIdSoulbound;
        uint256 itemIdCraftable;
        uint256 itemIdClaimable;
        uint256 itemIdFree;
    }

    struct Accounts {
        address admin;
        address gameMaster;
        address player1;
        address player2;
        address character1;
        address character2;
        address rando;
    }

    struct HatsContracts {
        HatsModuleFactory hatsModuleFactory;
        Hats hats;
    }

    struct Implementations {
        CharacterSheetsImplementation characterSheets;
        ExperienceImplementation experience;
        ItemsImplementation items;
        ItemsManagerImplementation itemsManager;
        ClassesImplementation classes;
        ClonesAddressStorageImplementation clonesAddressStorage;
        CharacterEligibilityAdaptorV2 characterEligibilityAdaptorV2;
        CharacterEligibilityAdaptorV3 characterEligibilityAdaptorV3;
        ClassLevelAdaptor classLevelAdaptor;
        HatsAdaptor hatsAdaptor;
        AdminHatEligibilityModule adminModule;
        GameMasterHatEligibilityModule dmModule;
        PlayerHatEligibilityModule playerModule;
        CharacterHatEligibilityModule characterModule;
    }

    struct ERC6551Contracts {
        ERC6551Registry erc6551Registry;
        CharacterAccount erc6551Implementation;
    }

    // struct EncodedAddresses {
    //     bytes encodedImplementationAddresses;
    //     bytes encodedModuleAddresses;
    //     bytes encodedAdaptorAddresses;
    //     bytes encodedExternalAddresses;
    // }
}
