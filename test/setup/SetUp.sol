// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
pragma abicoder v2;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import {TestStructs} from "./helpers/TestStructs.sol";
import {Accounts} from "./helpers/Accounts.sol";

//fatory
import {CharacterSheetsFactory} from "../../src/CharacterSheetsFactory.sol";
// implementations
import {CharacterSheetsImplementation} from "../../src/implementations/CharacterSheetsImplementation.sol";
import {ItemsImplementation} from "../../src/implementations/ItemsImplementation.sol";
import {ItemsManagerImplementation} from "../../src/implementations/ItemsManagerImplementation.sol";
import {ClassesImplementation} from "../../src/implementations/ClassesImplementation.sol";
import {ExperienceImplementation} from "../../src/implementations/ExperienceImplementation.sol";

//address storage
import {ImplementationAddressStorage} from "../../src/lib/ImplementationAddressStorage.sol";
import {ClonesAddressStorage} from "../../src/lib/ClonesAddressStorage.sol";

//adaptors
import {CharacterEligibilityAdaptor} from "../../src/adaptors/CharacterEligibilityAdaptor.sol";
import {ClassLevelAdaptor} from "../../src/adaptors/ClassLevelAdaptor.sol";
import {HatsAdaptor} from "../../src/adaptors/HatsAdaptor.sol";

//erc6551
import {ERC6551Registry} from "../../src/mocks/ERC6551Registry.sol";
import {CharacterAccount} from "../../src/CharacterAccount.sol";

// multi Send
import {MultiSend} from "../../src/lib/MultiSend.sol";
import {Category} from "../../src/lib/MultiToken.sol";

// hats imports
import {HatsModuleFactory} from "hats-module/HatsModuleFactory.sol";
import {Hats} from "hats-protocol/Hats.sol";

// hats eligibility modules
import {AdminHatEligibilityModule} from "../../src/adaptors/hats-modules/AdminHatEligibilityModule.sol";
import {DungeonMasterHatEligibilityModule} from "../../src/adaptors/hats-modules/DungeonMasterHatEligibilityModule.sol";
import {PlayerHatEligibilityModule} from "../../src/adaptors/hats-modules/PlayerHatEligibilityModule.sol";
import {CharacterHatEligibilityModule} from "../../src/adaptors/hats-modules/CharacterHatEligibilityModule.sol";

//test and mocks
import {IMolochDAO} from "../../src/interfaces/IMolochDAO.sol";
import {Moloch} from "../../src/mocks/MockMoloch.sol";

import "murky/src/Merkle.sol";

contract SetUp is Test, Accounts, TestStructs {
    DeployedContracts public deployments;
    CharacterSheetsFactory public characterSheetsFactory;
    ImplementationAddressStorage public implementationStorage;

    Implementations public implementations;
    HatsContracts public hatsContracts;
    ERC6551Contracts public erc6551Contracts;

    Moloch public dao;
    Merkle public merkle;

    MultiSend public multisend;

    function setUp() public {
        vm.startPrank(accounts.admin);
        _deployImplementations();
        _deployHatsContracts();
        _deployErc6551Contracts();

        implementationStorage = new ImplementationAddressStorage();

        _deployCharacterSheetsFactory();
        vm.stopPrank();
    }

    function _deployImplementations() internal {
        dao = new Moloch();
        merkle = new Merkle();

        implementations.characterSheets = new CharacterSheetsImplementation();
        implementations.items = new ItemsImplementation();
        implementations.itemsManager = new ItemsManagerImplementation();
        implementations.experience = new ExperienceImplementation();
        implementations.classes = new ClassesImplementation();
        implementations.clonesAddressStorage = new ClonesAddressStorage();

        implementations.characterEligibilityAdaptor = new CharacterEligibilityAdaptor();
        implementations.classLevelAdaptor = new ClassLevelAdaptor();
        implementations.hatsAdaptor = new HatsAdaptor();
        implementations.adminModule = new AdminHatEligibilityModule("v 0.1");
        implementations.dmModule = new DungeonMasterHatEligibilityModule("v 0.1");
        implementations.playerModule = new PlayerHatEligibilityModule("v 0.1");
        implementations.characterModule = new CharacterHatEligibilityModule("v 0.1");

        vm.label(address(dao), "Moloch");
        vm.label(address(merkle), "Merkle");
        vm.label(address(implementations.characterSheets), "Character Sheets");
        vm.label(address(implementations.items), "Items");
        vm.label(address(implementations.itemsManager), "Items Manager");
        vm.label(address(implementations.experience), "Experience");
        vm.label(address(implementations.classes), "Classes");
        vm.label(address(implementations.clonesAddressStorage), "Clones Address Storage");
        vm.label(address(implementations.characterEligibilityAdaptor), "Character Eligibility adaptor");
        vm.label(address(implementations.classLevelAdaptor), "Class Level adaptor");
        vm.label(address(implementations.hatsAdaptor), "Hats adaptor");
        vm.label(address(implementations.adminModule), "Admin Hats Eligibility adaptor");
        vm.label(address(implementations.dmModule), "Dungeon Master Hats Eligibility adaptor");
        vm.label(address(implementations.playerModule), "Player Hats Eligibility adaptor");
        vm.label(address(implementations.characterModule), "Character Hats Eligibility adaptor");
    }

    function _deployHatsContracts() internal {
        hatsContracts.hats = new Hats("Test Hats", "test_hats_base_img_uri");
        hatsContracts.hatsModuleFactory = new HatsModuleFactory(hatsContracts.hats, "test hats factory");

        vm.label(address(hatsContracts.hats), "Hats Contract");
        vm.label(address(hatsContracts.hatsModuleFactory), "Hats Module Factory");
    }

    function _deployErc6551Contracts() internal {
        erc6551Contracts.erc6551Registry = new ERC6551Registry();
        erc6551Contracts.erc6551Implementation = new CharacterAccount();

        vm.label(address(erc6551Contracts.erc6551Registry), "ERC6551 Registry");
        vm.label(address(erc6551Contracts.erc6551Implementation), "ERC6551 Character Account Implementation");
    }

    function _deployCharacterSheetsFactory() internal {
        characterSheetsFactory = new CharacterSheetsFactory();
        implementationStorage = new ImplementationAddressStorage();
        multisend = new MultiSend();

        vm.label(address(characterSheetsFactory), "Character Sheets Factory");
        vm.label(address(implementationStorage), "Implementation Address Storage");
        vm.label(address(multisend), "MultiSend");

        bytes memory encodedImplementationAddresses = abi.encode(
            implementations.characterSheets,
            implementations.items,
            implementations.classes,
            implementations.experience,
            implementations.clonesAddressStorage,
            implementations.itemsManager,
            address(erc6551Contracts.erc6551Implementation)
        );

        bytes memory encodedAdaptorsAndModuleAddresses = abi.encode(
            implementations.adminModule,
            implementations.dmModule,
            implementations.playerModule,
            implementations.characterModule,
            implementations.hatsAdaptor,
            implementations.characterEligibilityAdaptor,
            implementations.classLevelAdaptor
        );

        bytes memory encodedExternalAddresses = abi.encode(
            address(erc6551Contracts.erc6551Registry),
            address(hatsContracts.hats),
            address(hatsContracts.hatsModuleFactory)
        );
        implementationStorage.initialize(
            encodedImplementationAddresses, encodedAdaptorsAndModuleAddresses, encodedExternalAddresses
        );
        characterSheetsFactory.initialize(address(implementationStorage));
    }
}
