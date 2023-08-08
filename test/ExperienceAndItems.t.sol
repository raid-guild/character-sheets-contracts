// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;
pragma abicoder v2;

import "forge-std/Test.sol";
import "../src/implementations/ExperienceAndItemsImplementation.sol";
import "./helpers/SetUp.sol";
import "../src/lib/Structs.sol";

contract ExperienceAndItemsTest is Test, SetUp {

    function testCreateClass() public {
        vm.prank(admin);
        (uint256 _tokenId, uint256 _classId) = experience.createClassType(createNewClass("Ballerina"));
        (uint256 tokenId, string memory name, uint256 supply, string memory cid) = experience.classes(_classId);
        
        assertEq(experience.totalClasses(), 2);
        assertEq(tokenId, 3);
        assertEq(_tokenId, 3);
        assertEq(_classId, 2);
        assertEq(keccak256(abi.encode(name)), keccak256(abi.encode("Ballerina")));
        assertEq(supply, 0);
        assertEq(keccak256(abi.encode(cid)), keccak256(abi.encode("test_class_cid/")));
    }

    function testAssignClass() public {
        uint256 playerId = characterSheets.memberAddressToTokenId(player1);
        vm.startPrank(admin);

        (uint256 tokenId, uint256 classId) = experience.createClassType(createNewClass("Ballerina"));

        CharacterSheet memory player = characterSheets.getCharacterSheetByPlayerId(playerId);
        experience.assignClass(player.ERC6551TokenAddress, classId);
        vm.stopPrank();

        assertEq(experience.balanceOf(player.ERC6551TokenAddress, tokenId), 1);
    }

    function testCreateItemType() public {
        Item memory newItem = createNewItem("Pirate_Hat", false, bytes32(0));
        vm.prank(admin);
        (uint256 _tokenId, uint256 _itemId) = experience.createItemType(newItem);

        (
            uint256 tokenId,
            string memory name,
            uint256 supply,
            uint256 supplied,
            uint256 experinceCost,
            uint256 hatId,
            bool soulbound,
            bytes32 claimable,
            string memory cid
        ) = experience.items(_itemId);

        assertEq(experience.totalItemTypes(), 2);
        assertEq(keccak256(abi.encode(name)), keccak256(abi.encode("Pirate_Hat")));
        assertEq(tokenId, 3);
        assertEq(_tokenId, 3);
        assertEq(supply, 10**18);
        assertEq(hatId, 0);
        assertEq(supplied, 0);
        assertEq(experinceCost,100);
        assertEq(soulbound, false);
        assertEq(claimable, bytes32(0));
        assertEq(keccak256(abi.encode(cid)), keccak256(abi.encode('test_item_cid/')));
        assertEq(keccak256(abi.encode(experience.uri(tokenId))), keccak256(abi.encode('test_base_uri_experience/test_item_cid/')), "uris not right");

    }

    function testCreateItemTypeRevertItemExists() public {
        Item memory newItem = createNewItem("Pirate_Hat", false, bytes32(0));

        vm.startPrank(admin);        
        experience.createItemType(newItem);

        vm.expectRevert("Item already exists.");
        experience.createItemType(newItem);

        vm.stopPrank();
    }

    function testCreateItemTypeRevertAccessControl() public {
        Item memory newItem = createNewItem("Pirate_Hat", false, bytes32(0));

        vm.startPrank(player2);  
        vm.expectRevert("You must be the Dungeon Master");      
        experience.createItemType(newItem);
        vm.stopPrank();
    }

    function testDropLoot()public{

        vm.startPrank(admin);
        Item memory newItem = createNewItem("staff", false, bytes32(0));
        address player1NFT = characterSheets.getCharacterSheetByPlayerId(characterSheets.memberAddressToTokenId(player1)).ERC6551TokenAddress;

        (uint256 _tokenId, uint256 _itemId) = experience.createItemType(newItem);
        address[] memory players = new address[](1);
        players[0] = player1NFT;
        uint256[] memory itemIds = new uint256[](3);
        itemIds[0] = 0;
        itemIds[1] = 1;
        itemIds[2] = _itemId;

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 10000;
        amounts[1] = 1;
        amounts[2] = 1;

        experience.dropLoot(players, itemIds, amounts);
        vm.stopPrank();

        assertEq(experience.balanceOf(player1NFT, _tokenId), 1, "tokenId 3 not equal");
        assertEq(experience.balanceOf(player1NFT, 0), 10000, "exp not equal");
        assertEq(experience.balanceOf(player1NFT, 1), 1, "token id 1 not equal");
    }

    function testDropLootRevert()public{
        
    }

    function testClaimItem() public {
          Item memory newItem = createNewItem("staff", false, bytes32(0));
          vm.prank(admin);
        (uint256 _tokenId, uint256 _itemId) = experience.createItemType(newItem);

        uint256 playerId = characterSheets.memberAddressToTokenId(player1);

        address nftAddress = characterSheets.getCharacterSheetByPlayerId(playerId).ERC6551TokenAddress;

        uint256[] memory itemIds = new uint256[](2);
        itemIds[0] = _itemId;
        itemIds[1] = 4;
        address[] memory claimers = new address[](2);
        claimers[0] = nftAddress;
        claimers[1] = player2;
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1;
        amounts[1] = 100;

        (bytes32[] memory proof, bytes32 root) = generateMerkleRootAndProof(itemIds, claimers, amounts, 0);
        
        dropExp(nftAddress, 100000);

        vm.prank(admin);
        experience.updateItemClaimable(_itemId, root);

        uint256[] memory itemIds2 = new uint256[](1);
        bytes32[][] memory proofs = new bytes32[][](1);
        uint256[] memory amounts2 = new uint256[](1);
        itemIds2[0] = _itemId;
        amounts2[0] = 1;
        proofs[0] = proof;

        vm.prank(nftAddress);
        experience.claimItems(itemIds2, amounts2, proofs);

        assertEq(experience.balanceOf(nftAddress, _tokenId), 1, "Balance not equal");
    }

    function testFindItemByName() public {
        (uint256 tokenId, uint256 itemId) = experience.findItemByName("test_item");
        assertEq(itemId, 1);
        assertEq(tokenId, 1);

        vm.expectRevert("No item found.");
        experience.findItemByName("no_Item");
    }


    function testFindClassByName() public {
        (uint256 tokenId, uint256 classId) = experience.findClassByName("test_class");
        assertEq(classId, 1);
        assertEq(tokenId, 2);

        vm.expectRevert("No class found.");
        experience.findClassByName("no_class");
    }


}
