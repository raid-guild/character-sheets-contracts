// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;
pragma abicoder v2;

import "forge-std/Test.sol";
import "../../src/implementations/ExperienceAndItemsImplementation.sol";
import "../../src/factories/CharacterSheetsFactory.sol";
import "../../src/implementations/CharacterSheetsImplementation.sol";
import "../../src/interfaces/IMolochDAO.sol";
import "../../src/mocks/mockMoloch.sol";
import "../../src/mocks/MockHats.sol";
import "../../src/lib/Structs.sol";
import "murky/Merkle.sol";
import "@openzeppelin/contracts-upgradeable/proxy/ClonesUpgradeable.sol";
import {ERC6551Registry} from "../../src/mocks/ERC6551Registry.sol";
import {SimpleERC6551Account} from "../../src/mocks/ERC6551Implementation.sol";

contract SetUp is Test {
    ExperienceAndItemsImplementation experienceAndItemsImplementation;
    ExperienceAndItemsImplementation experience;
    CharacterSheetsFactory characterSheetsFactory;
    CharacterSheetsImplementation characterSheetsImplementation;
    CharacterSheetsImplementation characterSheets;
    MockHats hats;
    address characterSheetsAddress;

    Merkle merkle = new Merkle();




    address experienceAddress;

    using ClonesUpgradeable for address;
    using stdJson for string;

    address admin = address(0xdeadce11);
    address player1 = address(0xbeef);
    address player2 = address(0xbabe);
    Moloch dao;

    ERC6551Registry erc6551Registry;
    SimpleERC6551Account erc6551Implementation;

    function setUp() public {
        

        Item memory newItem = createNewItem("test_item", false, bytes32(0));
        vm.startPrank(admin);

        dao = new Moloch();
        hats = new MockHats("mockhat", "mockHat_img/");
        vm.label(address(dao), 'Moloch');

        characterSheetsFactory= new CharacterSheetsFactory();
        experienceAndItemsImplementation = new ExperienceAndItemsImplementation();
        characterSheetsImplementation = new CharacterSheetsImplementation();
        characterSheetsFactory.initialize();

        vm.label(address(characterSheetsFactory), 'Character factory');        
        vm.label(address(characterSheetsImplementation), 'CharacterSheets Implementation');

        erc6551Registry = new ERC6551Registry();
        erc6551Implementation = new SimpleERC6551Account();

        dao.addMember(player1);
        dao.addMember(admin);
        characterSheetsFactory.updateCharacterSheetsImplementation(address(characterSheetsImplementation));
        characterSheetsFactory.updateExperienceAndItemsImplementation(address(experienceAndItemsImplementation));
        characterSheetsFactory.updateHats(address(hats));
        address[] memory dungeonMasters = new address[](1);
        dungeonMasters[0] = admin;
        (characterSheetsAddress, experienceAddress) = characterSheetsFactory.create(dungeonMasters, address(dao), 'test_base_uri_experience/', 'test_base_uri_character_sheets/');
        characterSheets = CharacterSheetsImplementation(characterSheetsAddress);
        characterSheets.setERC6551Registry(address(erc6551Registry));
        characterSheets.setERC6551Implementation(address(erc6551Implementation));

        bytes memory encodedData = abi.encode('Test Name', 'test_token_uri/');

        characterSheets.rollCharacterSheet(player1, encodedData);

      
        vm.label(address(experienceAndItemsImplementation), 'Gear Implementation');

        erc6551Registry = new ERC6551Registry();
        erc6551Implementation = new SimpleERC6551Account();
        experience = ExperienceAndItemsImplementation(experienceAddress);
        experience.createItemType(newItem);
        experience.createClassType(createNewClass('test_class'));
        vm.stopPrank();
     }

     function createNewItem(string memory _name, bool _soulbound, bytes32 _claimable)public pure returns(Item memory){
        return Item({tokenId: 0, name: _name, supply: 10**18, supplied: 0, experienceCost: 100, hatId: 0, soulbound: _soulbound, claimable: _claimable, cid: 'test_item_cid/'});
     }

     function createNewClass(string memory _name)public pure returns(Class memory){
        return Class({tokenId: 0, name: _name, supply: 0, cid: 'test_class_cid/'});
     }

   function dropExp(address player, uint256 amount)public{
        address[] memory players = new address[](1);
        players[0] = player;
        uint256[] memory itemIds = new uint256[](3);
        itemIds[0] = 0;
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = amount;
        vm.prank(admin);
        experience.dropLoot(players, itemIds, amounts);
   }

   function generateMerkleRootAndProof(uint256[] memory itemIds, address[] memory claimers, uint256[] memory amounts, uint256 indexOfProof) public view returns(bytes32[] memory proof, bytes32 root) {
      bytes32[] memory leaves = new bytes32[](itemIds.length);
      for(uint256 i =0; i< itemIds.length; i++){

         leaves[i] = keccak256(bytes.concat(keccak256(abi.encodePacked(itemIds[i], claimers[i], amounts[i]))));
               }
      proof = merkle.getProof(leaves, indexOfProof);
      root = merkle.getRoot(leaves);

   }
     
}