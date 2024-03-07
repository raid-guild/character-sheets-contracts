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
// hats eligibility modules
import {AddressHatsEligibilityModule} from "../../../src/mocks/AddressHatsEligibilityModule.sol";
import {ERC721HatsEligibilityModule} from "../../../src/mocks/ERC721HatsEligibilityModule.sol";
import {ERC6551HatsEligibilityModule} from "../../../src/adaptors/hats-modules/ERC6551HatsEligibilityModule.sol";
import {MultiERC6551HatsEligibilityModule} from
    "../../../src/adaptors/hats-modules/MultiERC6551HatsEligibilityModule.sol";

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
        AddressHatsEligibilityModule addressModule;
        ERC721HatsEligibilityModule erc721Module;
        ERC6551HatsEligibilityModule erc6551Module;
        MultiERC6551HatsEligibilityModule multiErc6551Module;
    }

    struct Adaptors {
        ICharacterEligibilityAdaptor molochV2EligibilityAdaptor;
        ICharacterEligibilityAdaptor molochV3EligibilityAdaptor;
        ClassLevelAdaptor classLevelAdaptor;
        HatsAdaptor hatsAdaptor;
    }

    struct ERC6551Contracts {
        ERC6551Registry erc6551Registry;
        CharacterAccount erc6551Implementation;
    }
}
