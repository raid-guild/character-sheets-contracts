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
        Item memory newItem = createNewItem("Pirate", false, true);
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
            bool claimable,
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
        assert(claimable == true);
        assert(keccak256(abi.encode(cid)) == keccak256(abi.encode('test_item_cid/')));
    }

    function testDropLoot()public{

        vm.startPrank(admin);
        Item memory newItem = createNewItem("staff", false, true);
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
        console2.log(experience.uri(1));
        uint256 tokenId = characterSheets.getPlayerIdByMemberAddress(player1);
        address nftAddress = characterSheets.getCharacterSheetByPlayerId(tokenId).ERC6551TokenAddress;

        dropExp(player1, 100000);
        uint256[] memory itemIds = new uint256[](1);
        uint256[] memory amounts = new uint256[](1);
        itemIds[0] = 1;
        amounts[0] = 1;
        vm.prank(player1);
        experience.claimItems(itemIds, amounts);
        assertEq(experience.balanceOf(nftAddress, 1), 1, "Balance not equal");
    }

    function testFindItemByName() public view {
        (uint256 tokenId, uint256 itemId) = experience.findItemByName("test_item");
        assert(itemId == 1);
        assert(tokenId == 1);
    }

    function testFindClassByName() public view {
        (uint256 tokenId, uint256 classId) = experience.findClassByName("test_class");
        assert(classId == 1);
        assert(tokenId == 2);
    }

}
