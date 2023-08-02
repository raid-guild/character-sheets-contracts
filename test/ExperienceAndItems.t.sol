// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;
pragma abicoder v2;

import "forge-std/Test.sol";
import "../src/implementations/ExperienceAndItemsImplementation.sol";
import "./helpers/SetUp.sol";

contract ExperienceAndItemsTest is Test, SetUp {

    function testCreateClass() public {
        vm.prank(admin);
        (uint256 _tokenId, uint256 _classId) = experience.createClassType(createNewClass("Ballerina"));
        (uint256 tokenId, string memory name, uint256 supply, string memory cid) = experience.classes(_classId);
        assert(experience.totalClasses() == 2);
        assert(tokenId == 3);
        assert(_tokenId == 3);
        assert(_classId == 2);
        assert(keccak256(abi.encode(name)) == keccak256(abi.encode("Ballerina")));
        assert(supply == 0);
        assert(keccak256(abi.encode(cid)) == keccak256(abi.encode("test_class_cid/")));
    }

    function testAssignClass() public {
        vm.startPrank(admin);

        (uint256 tokenId, uint256 classId) = experience.createClassType(createNewClass("Ballerina"));
        experience.assignClass(characterSheets.getPlayerIdByMemberAddress(player1), classId);
        vm.stopPrank();

        address playerNft =
            characterSheets.getCharacterSheetByPlayerId(characterSheets.getPlayerIdByMemberAddress(player1)).ERC6551TokenAddress;

        assert(experience.balanceOf(playerNft, tokenId) == 1);
    }

    function testCreateItemType() public {
        Item memory newItem = createNewItem("Pirate", false, bytes32(0));
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

        assert(experience.totalItemTypes() == 2);
        assert(keccak256(abi.encode(name)) == keccak256(abi.encode("Pirate")));
        assert(tokenId == 3);
        assert(_tokenId == 3);
        assert(supply == 10**18);
        assert(supplied ==0 );
        assert(experinceCost == 100);
        assert(soulbound == false);
        assert(claimable == bytes32(0));
        assert(keccak256(abi.encode(cid)) == keccak256(abi.encode('test_item_cid/')));
    }

    function testDropLoot()public{

        vm.startPrank(admin);
        Item memory newItem = createNewItem("staff", false, bytes32(0));
        (uint256 _tokenId, uint256 _itemId) = experience.createItemType(newItem);
        address[] memory players = new address[](1);
        players[0] = player1;
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

        address player1NFT = characterSheets.getCharacterSheetByPlayerId(characterSheets.getPlayerIdByMemberAddress(player1)).ERC6551TokenAddress;

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

        uint256 playerId = characterSheets.getPlayerIdByMemberAddress(player1);

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
        dropExp(player1, 100000);
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

    function testFindItemByName() public view {
        (uint256 tokenId, uint256 itemId) = experience.findItemByName("test_item");
        assert(itemId == 1);
        assert(tokenId == 1);
    }

    function testFindItemRevert() public {
        vm.expectRevert("No item found.");
        (uint256 tokenId, uint256 itemId) = experience.findItemByName("Test_Item");
    }

    function testFindClassByName() public view {
        (uint256 tokenId, uint256 classId) = experience.findClassByName("test_class");
        assert(classId == 1);
        assert(tokenId == 2);
    }

    function testFindClassRevert() public {
                vm.expectRevert("No class found.");
        (uint256 tokenId, uint256 itemId) = experience.findClassByName("Test_Item");
    }

}
