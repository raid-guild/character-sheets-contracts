// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
pragma abicoder v2;

//solhint-disable

import "forge-std/Test.sol";
import "forge-std/console2.sol";

import "../src/implementations/ItemsImplementation.sol";
import {RequirementsTree, RequirementNode} from "../src/implementations/ItemsManagerImplementation.sol";
import "../src/lib/Structs.sol";
import "./setup/SetUp.t.sol";

contract ItemsTest is SetUp {
    event ItemDeleted(uint256 itemId);

    function testCreateClaimableItem() public {
        Item memory returnedItem = deployments.items.getItem(itemsData.itemIdClaimable);
        bytes memory itemRequirements = deployments.itemsManager.getClaimRequirements(itemsData.itemIdClaimable);
        RequirementNode memory node = RequirementsTree.decode(itemRequirements);
        string memory cid = deployments.items.uri(itemsData.itemIdClaimable);

        assertEq(itemsData.itemIdClaimable, 1, "incorrect item ID");
        assertEq(deployments.items.totalItemTypes(), 4, "incorrect number of items");
        assertEq(returnedItem.supply, 10 ** 18, "incorrect supply");
        assertEq(returnedItem.supplied, 0, "incorrect supplied amount");
        assertEq(node.operator, 0, "incorrect operator");
        assertEq(node.children.length, 0, "incorrect number of children");
        Asset memory asset = node.asset;
        assertEq(uint8(asset.category), uint8(Category.ERC20), "incorrect asset category");
        assertEq(asset.assetAddress, address(deployments.experience), "incorrect asset address");
        assertEq(asset.id, 0, "incorrect asset ID");
        assertEq(asset.amount, 100, "incorrect amount");
        assertEq(returnedItem.soulbound, true);
        assertEq(returnedItem.craftable, false);
        assertEq(returnedItem.claimable, bytes32(0));
        assertEq(cid, "test_base_uri_items/test_item_cid/", "incorrect CID");
    }

    function testCreateCraftableItem() public {
        Item memory returnedItem = deployments.items.getItem(itemsData.itemIdCraftable);
        bytes memory itemRequirements = deployments.itemsManager.getCraftRequirements(itemsData.itemIdCraftable);
        CraftItem[] memory craftRequirements = abi.decode(itemRequirements, (CraftItem[]));
        string memory cid = deployments.items.uri(itemsData.itemIdCraftable);

        assertEq(itemsData.itemIdCraftable, 2, "incorrect item ID");
        assertEq(deployments.items.totalItemTypes(), 4, "incorrect number of items");
        assertEq(returnedItem.supply, 10 ** 18, "incorrect supply");
        assertEq(returnedItem.supplied, 0, "incorrect supplied amount");
        assertEq(craftRequirements.length, 1, "incorrect number of craft requirements");
        assertEq(craftRequirements[0].amount, 1, "incorrect amount");
        assertEq(craftRequirements[0].itemId, itemsData.itemIdSoulbound, "incorrect item ID");
        assertEq(returnedItem.soulbound, false);
        assertEq(returnedItem.craftable, true);
        assertEq(returnedItem.claimable, bytes32(keccak256("null")));
        assertEq(cid, "test_base_uri_items/test_item_cid/", "incorrect CID");
    }

    function testDropLoot() public {
        dao.addMember(accounts.rando);

        vm.prank(accounts.rando);
        uint256 randoId = deployments.characterSheets.rollCharacterSheet("test_token_uri1/");

        vm.startPrank(accounts.gameMaster);

        address randoNPC = deployments.characterSheets.getCharacterSheetByCharacterId(randoId).accountAddress;

        uint256 _itemId =
            deployments.items.createItemType(createNewItem(false, false, bytes32(0), 1, createEmptyRequiredAssets()));
        assertEq(_itemId, 4, "incorrect itemId1");

        uint256 _itemId2 =
            deployments.items.createItemType(createNewItem(false, false, bytes32(0), 1, createEmptyRequiredAssets()));
        assertEq(_itemId2, 5, "incorrect itemId2");

        address[] memory players = new address[](2);
        players[0] = accounts.character1;
        players[1] = randoNPC;

        uint256[][] memory itemIds = new uint256[][](2);
        itemIds[0] = new uint256[](2);
        itemIds[0][0] = _itemId;
        itemIds[0][1] = _itemId2;

        itemIds[1] = new uint256[](2);
        itemIds[1][0] = _itemId;
        itemIds[1][1] = _itemId2;

        uint256[][] memory amounts = new uint256[][](2);
        amounts[0] = new uint256[](2);
        amounts[0][0] = 10000;
        amounts[0][1] = 1;
        amounts[1] = new uint256[](2);
        amounts[1][0] = 10001;
        amounts[1][1] = 2;

        deployments.experience.dropExp(accounts.character1, 100 * 10000);
        deployments.experience.dropExp(randoNPC, 100 * 10001);

        deployments.items.dropLoot(players, itemIds, amounts);
        vm.stopPrank();

        assertEq(deployments.items.balanceOf(accounts.character1, _itemId), 10000, "1: token id 0 not equal");
        assertEq(deployments.items.balanceOf(accounts.character1, _itemId2), 1, "1: token id 1 not equal");

        assertEq(deployments.items.balanceOf(randoNPC, _itemId), 10001, "2: token id 0 not equal");
        assertEq(deployments.items.balanceOf(randoNPC, _itemId2), 2, "2: token id 1 not equal");
    }

    function testClaimItem() public {
        vm.startPrank(accounts.gameMaster);
        uint256 _itemId1 = deployments.items.createItemType(
            createNewItem(
                false, true, bytes32(0), 1, createRequiredAsset(Category.ERC20, address(deployments.experience), 0, 100)
            )
        );
        uint256 _itemId2 = deployments.items.createItemType(
            createNewItem(
                false, true, bytes32(0), 1, createRequiredAsset(Category.ERC20, address(deployments.experience), 0, 100)
            )
        );

        // deployments.items.addItemRequirement(
        //     _itemId2, uint8(Category.ERC1155), address(deployments.classes), classData.classId, 1
        // );

        // need at least two leafs to create merkle tree
        uint256[] memory itemIds = new uint256[](2);
        itemIds[0] = _itemId1;
        itemIds[1] = _itemId2;
        address[] memory claimers = new address[](2);
        claimers[0] = accounts.character1;
        claimers[1] = accounts.player1;
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1;
        amounts[1] = 2;

        (bytes32[] memory proof, bytes32 root) = generateMerkleRootAndProof(itemIds, claimers, amounts, 0);

        deployments.items.updateItemClaimable(_itemId1, root, 1);

        vm.stopPrank();

        vm.prank(accounts.gameMaster);
        deployments.experience.dropExp(accounts.character1, 1000);

        vm.prank(accounts.gameMaster);
        deployments.classes.assignClass(accounts.character1, classData.classId);

        vm.prank(accounts.character1);
        deployments.items.obtainItems(_itemId1, 1, proof);

        assertEq(deployments.items.balanceOf(accounts.character1, _itemId1), 1, "Balance not equal");

        assertEq(deployments.experience.balanceOf(accounts.character1), 1000);
    }

    function testURI() public {
        string memory _uri = deployments.items.uri(0);
        assertEq(_uri, "test_base_uri_items/test_item_cid/", "incorrect uri returned");
    }

    function testDeleteItem() public {
        vm.startPrank(accounts.gameMaster);
        uint256 newItemId = deployments.items.createItemType(
            createNewItem(
                true, true, bytes32(0), 1, createRequiredAsset(Category.ERC20, address(deployments.experience), 0, 100)
            )
        );
        vm.expectEmit();
        emit ItemDeleted(newItemId);
        deployments.items.deleteItem(newItemId);
        vm.stopPrank();
        Item memory deleted = deployments.items.getItem(newItemId);

        assertEq(deleted.enabled, false, "item enabled");
    }

    function testCraftItem() public {
        vm.prank(accounts.gameMaster);
        uint256 _itemId =
            deployments.items.createItemType(createNewItem(false, false, bytes32(0), 1, createEmptyRequiredAssets()));
        assertEq(_itemId, 4, "incorrect itemId");

        vm.prank(accounts.gameMaster);
        uint256 craftableItemId = deployments.items.createItemType(
            createNewItem(true, true, bytes32(0), 1, createCraftingRequirement(_itemId, 100))
        );

        address[] memory players = new address[](1);
        players[0] = accounts.character1;

        uint256[][] memory itemIds = new uint256[][](1);
        itemIds[0] = new uint256[](1);
        itemIds[0][0] = _itemId;

        uint256[][] memory amounts = new uint256[][](1);
        amounts[0] = new uint256[](1);
        amounts[0][0] = 100;

        vm.prank(accounts.gameMaster);
        deployments.items.dropLoot(players, itemIds, amounts);
        assertEq(deployments.items.balanceOf(accounts.character1, _itemId), 100, "item not dropped");

        // should succeed with requirements met
        vm.startPrank(accounts.character1);

        // must approve item manager to transfer items
        deployments.items.setApprovalForAll(address(deployments.itemsManager), true);

        bytes32[] memory proof = new bytes32[](0);

        deployments.items.obtainItems(craftableItemId, 1, proof);

        vm.stopPrank();

        assertEq(deployments.items.balanceOf(accounts.character1, craftableItemId), 1, "item not crafted");
        assertEq(deployments.items.balanceOf(accounts.character1, _itemId), 0, "item not consumed in crafting");
    }

    function testDismantleItems() public {
        vm.startPrank(accounts.gameMaster);

        uint256 _itemId1 =
            deployments.items.createItemType(createNewItem(false, false, bytes32(0), 1, createEmptyRequiredAssets()));
        assertEq(_itemId1, 4, "incorrect itemId");

        uint256 _itemId2 =
            deployments.items.createItemType(createNewItem(false, false, bytes32(0), 1, createEmptyRequiredAssets()));
        assertEq(_itemId2, 5, "incorrect itemId");

        address[] memory players = new address[](1);
        players[0] = accounts.character1;

        uint256[][] memory itemIds = new uint256[][](1);
        itemIds[0] = new uint256[](2);
        itemIds[0][0] = _itemId1;
        itemIds[0][1] = _itemId2;

        uint256[][] memory amounts = new uint256[][](1);
        amounts[0] = new uint256[](2);
        amounts[0][0] = 100;
        amounts[0][1] = 200;

        deployments.items.dropLoot(players, itemIds, amounts);
        assertEq(deployments.items.balanceOf(accounts.character1, _itemId1), 100, "item1 not dropped");
        assertEq(deployments.items.balanceOf(accounts.character1, _itemId2), 200, "item2 not dropped");

        bytes memory requiredAssets;
        {
            CraftItem[] memory requirements = new CraftItem[](2);
            requirements[0] = CraftItem(_itemId1, 50);
            requirements[1] = CraftItem(_itemId2, 100);

            requiredAssets = abi.encode(requirements);
        }

        uint256 craftableItemId =
            deployments.items.createItemType(createNewItem(true, true, bytes32(0), 2, requiredAssets));

        vm.stopPrank();

        // should succeed with requirements met
        vm.startPrank(accounts.character1);
        // approve the spending of required items
        deployments.items.setApprovalForAll(address(deployments.itemsManager), true);

        bytes32[] memory proof = new bytes32[](0);

        deployments.items.obtainItems(craftableItemId, 2, proof);

        assertEq(deployments.items.balanceOf(accounts.character1, _itemId1), 0, "item1 not consumed in crafting");
        assertEq(deployments.items.balanceOf(accounts.character1, _itemId2), 0, "item2 not consumed in crafting");

        // should revert if trying to dismantle un-crafted item
        vm.expectRevert(Errors.CraftableError.selector);
        deployments.items.dismantleItems(0, 1);

        //should revert if trying to dismantle more than have been crafted
        vm.expectRevert(Errors.InsufficientBalance.selector);
        deployments.items.dismantleItems(craftableItemId, 4);

        //should succeed
        deployments.items.dismantleItems(craftableItemId, 1);

        assertEq(deployments.items.balanceOf(accounts.character1, craftableItemId), 1, "item not burnt");
        assertEq(deployments.items.balanceOf(accounts.character1, _itemId1), 50, "item1 not returned");
        assertEq(deployments.items.balanceOf(accounts.character1, _itemId2), 100, "item2 not returned");

        //should dismantle remaining items
        deployments.items.dismantleItems(craftableItemId, 1);

        assertEq(deployments.items.balanceOf(accounts.character1, craftableItemId), 0, "item 2 not burnt");
        assertEq(deployments.items.balanceOf(accounts.character1, _itemId1), 100, "item1 not returned");
        assertEq(deployments.items.balanceOf(accounts.character1, _itemId2), 200, "item2 not returned");
        vm.stopPrank();
    }

    // UNHAPPY PATH
    function testCreateItemTypeRevert() public {
        bytes memory newItem = createNewItem(false, false, bytes32(0), 1, createEmptyRequiredAssets());

        vm.startPrank(accounts.player2);
        vm.expectRevert(Errors.GameMasterOnly.selector);
        deployments.items.createItemType(newItem);
        vm.stopPrank();
    }

    function testDropLootRevert() public {
        vm.prank(accounts.gameMaster);
        uint256 _itemId = deployments.items.createItemType(
            createNewItem(false, false, bytes32(keccak256("null")), 0, createEmptyRequiredAssets())
        );
        assertEq(_itemId, 4);

        address[] memory players = new address[](1);
        players[0] = accounts.character1;
        uint256[][] memory itemIds = new uint256[][](2);
        itemIds[0] = new uint256[](2);
        itemIds[0][0] = 0;
        itemIds[0][1] = _itemId;
        itemIds[1] = new uint256[](2);
        itemIds[1][0] = 0;
        itemIds[1][1] = _itemId;

        uint256[][] memory amounts = new uint256[][](2);
        amounts[0] = new uint256[](2);
        amounts[0][0] = 10000;
        amounts[0][1] = 1;

        amounts[1] = new uint256[](2);
        amounts[1][0] = 1111;
        amounts[1][1] = 11;

        //revert wrong array lengths
        vm.prank(accounts.gameMaster);
        vm.expectRevert(Errors.LengthMismatch.selector);
        deployments.items.dropLoot(players, itemIds, amounts);

        //revert incorrect caller
        vm.prank(address(1));
        vm.expectRevert(Errors.GameMasterOnly.selector);
        deployments.items.dropLoot(players, itemIds, amounts);
    }

    function testCraftItemRevert() public {
        // should revert if item is not set to craftable
        vm.prank(accounts.character1);
        vm.expectRevert();
        bytes32[] memory proof = new bytes32[](0);
        deployments.items.obtainItems(0, 1, proof);

        vm.prank(accounts.gameMaster);
        uint256 craftableItemId = deployments.items.createItemType(
            createNewItem(true, true, bytes32(0), 1, createCraftingRequirement(3, 100))
        );

        //should revert if requirements not met
        vm.prank(accounts.character1);
        vm.expectRevert(Errors.InsufficientBalance.selector);
        deployments.items.obtainItems(craftableItemId, 1, proof);
    }

    function testClaimItemRevert() public {
        vm.startPrank(accounts.gameMaster);
        uint256 _itemId1 = deployments.items.createItemType(
            createNewItem(
                false, true, bytes32(0), 1, createRequiredAsset(Category.ERC20, address(deployments.experience), 0, 100)
            )
        );
        uint256 _itemId2 = deployments.items.createItemType(
            createNewItem(
                false,
                true,
                bytes32(0),
                1,
                createRequiredAsset(Category.ERC1155, address(deployments.classes), classData.classId, 1)
            )
        );
        uint256 _itemId3 = deployments.items.createItemType(
            createNewItem(
                false, true, bytes32(0), 1, createRequiredAsset(Category.ERC20, address(deployments.experience), 0, 100)
            )
        );

        // need at least two leafs to create merkle tree
        uint256[] memory itemIds = new uint256[](2);
        itemIds[0] = _itemId1;
        itemIds[1] = _itemId2;
        address[] memory claimers = new address[](2);
        claimers[0] = accounts.character1;
        claimers[1] = accounts.player1;
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1;
        amounts[1] = 2;

        (bytes32[] memory proof, bytes32 root) = generateMerkleRootAndProof(itemIds, claimers, amounts, 0);

        deployments.items.updateItemClaimable(_itemId1, root, 1);

        bytes32[] memory proof2 = new bytes32[](2);
        vm.stopPrank();

        // revert with not enough req items
        vm.prank(accounts.character1);
        vm.expectRevert(Errors.RequirementNotMet.selector);
        deployments.items.obtainItems(_itemId2, 1, proof2);

        vm.prank(accounts.gameMaster);
        deployments.experience.dropExp(accounts.character1, 1000);

        // revert wrong class
        vm.prank(accounts.character1);
        vm.expectRevert(Errors.RequirementNotMet.selector);
        deployments.items.obtainItems(_itemId2, 1, proof2);

        vm.prank(accounts.gameMaster);
        deployments.classes.assignClass(accounts.character1, classData.classId);

        //revert invalid proof
        vm.prank(accounts.character1);
        vm.expectRevert(Errors.InvalidProof.selector);
        deployments.items.obtainItems(_itemId1, 1, proof2);

        vm.prank(accounts.character1);
        deployments.items.obtainItems(_itemId1, 1, proof);

        //revert on second attempt to obtain
        vm.prank(accounts.character1);
        vm.expectRevert(abi.encodeWithSelector(Errors.CannotObtain.selector, 1));
        deployments.items.obtainItems(_itemId1, 1, proof);

        //revert if trying to obtain more than allowed amount
        vm.prank(accounts.character1);
        vm.expectRevert(abi.encodeWithSelector(Errors.CannotObtain.selector, 1));
        deployments.items.obtainItems(_itemId3, 5, proof);
    }

    function testComplexRequirementsClaimRevert() public {
        uint256 claimableItemId = createComplexClaimableItem();

        vm.startPrank(accounts.character1);
        bytes32[] memory proof = new bytes32[](0);

        vm.expectRevert(Errors.RequirementNotMet.selector);
        deployments.items.obtainItems(claimableItemId, 1, proof);

        vm.stopPrank();

        vm.prank(accounts.gameMaster);
        deployments.experience.dropExp(accounts.character1, 1500);

        vm.expectRevert(Errors.RequirementNotMet.selector);
        vm.prank(accounts.character1);
        deployments.items.obtainItems(claimableItemId, 1, proof);
    }

    function testComplexRequirementsClaimWithItem1() public {
        uint256 claimableItemId = createComplexClaimableItem();

        vm.startPrank(accounts.gameMaster);
        deployments.experience.dropExp(accounts.character1, 1500);
        {
            address[] memory players = new address[](1);
            players[0] = accounts.character1;
            uint256[][] memory itemIds = new uint256[][](1);
            itemIds[0] = new uint256[](1);
            itemIds[0][0] = claimableItemId - 2;
            uint256[][] memory amounts = new uint256[][](1);
            amounts[0] = new uint256[](1);
            amounts[0][0] = 100;

            deployments.items.dropLoot(players, itemIds, amounts);
        }
        vm.stopPrank();

        assertEq(deployments.items.balanceOf(accounts.character1, claimableItemId - 2), 100, "item not dropped");
        assertEq(deployments.items.balanceOf(accounts.character1, claimableItemId), 0, "item already claimed");

        vm.startPrank(accounts.character1);
        {
            bytes32[] memory proof = new bytes32[](0);

            deployments.items.obtainItems(claimableItemId, 1, proof);
        }

        vm.stopPrank();
        assertEq(deployments.items.balanceOf(accounts.character1, claimableItemId), 1, "item not claimed");
    }

    function testComplexRequirementsClaimWithItem1ForShallowNot() public {
        uint256 claimableItemId = createComplexClaimableItemWithShallowNot();

        vm.startPrank(accounts.gameMaster);
        deployments.experience.dropExp(accounts.character1, 1500);
        {
            address[] memory players = new address[](1);
            players[0] = accounts.character1;
            uint256[][] memory itemIds = new uint256[][](1);
            itemIds[0] = new uint256[](1);
            itemIds[0][0] = claimableItemId - 2;
            uint256[][] memory amounts = new uint256[][](1);
            amounts[0] = new uint256[](1);
            amounts[0][0] = 100;

            deployments.items.dropLoot(players, itemIds, amounts);
        }
        vm.stopPrank();

        assertEq(deployments.items.balanceOf(accounts.character1, claimableItemId - 2), 100, "item not dropped");
        assertEq(deployments.items.balanceOf(accounts.character1, claimableItemId), 0, "item already claimed");

        vm.startPrank(accounts.character1);
        {
            bytes32[] memory proof = new bytes32[](0);

            deployments.items.obtainItems(claimableItemId, 1, proof);
        }

        vm.stopPrank();
        assertEq(deployments.items.balanceOf(accounts.character1, claimableItemId), 1, "item not claimed");
    }

    function testComplexRequirementsClaimWithItem2() public {
        uint256 claimableItemId = createComplexClaimableItem();

        vm.startPrank(accounts.gameMaster);
        deployments.experience.dropExp(accounts.character1, 1500);
        {
            address[] memory players = new address[](1);
            players[0] = accounts.character1;
            uint256[][] memory itemIds = new uint256[][](1);
            itemIds[0] = new uint256[](1);
            itemIds[0][0] = claimableItemId - 1;
            uint256[][] memory amounts = new uint256[][](1);
            amounts[0] = new uint256[](1);
            amounts[0][0] = 200;

            deployments.items.dropLoot(players, itemIds, amounts);
        }
        vm.stopPrank();

        assertEq(deployments.items.balanceOf(accounts.character1, claimableItemId - 1), 200, "item not dropped");
        assertEq(deployments.items.balanceOf(accounts.character1, claimableItemId), 0, "item already claimed");

        vm.startPrank(accounts.character1);
        {
            bytes32[] memory proof = new bytes32[](0);

            deployments.items.obtainItems(claimableItemId, 1, proof);
        }

        vm.stopPrank();
        assertEq(deployments.items.balanceOf(accounts.character1, claimableItemId), 1, "item not claimed");
    }

    function testComplexRequirementsClaimRevertWithTooMuchExp() public {
        uint256 claimableItemId = createComplexClaimableItem();

        vm.startPrank(accounts.gameMaster);
        deployments.experience.dropExp(accounts.character1, 3500);
        {
            address[] memory players = new address[](1);
            players[0] = accounts.character1;
            uint256[][] memory itemIds = new uint256[][](1);
            itemIds[0] = new uint256[](1);
            itemIds[0][0] = claimableItemId - 1;
            uint256[][] memory amounts = new uint256[][](1);
            amounts[0] = new uint256[](1);
            amounts[0][0] = 200;

            deployments.items.dropLoot(players, itemIds, amounts);
        }
        vm.stopPrank();

        assertEq(deployments.items.balanceOf(accounts.character1, claimableItemId - 1), 200, "item not dropped");
        assertEq(deployments.items.balanceOf(accounts.character1, claimableItemId), 0, "item already claimed");

        vm.startPrank(accounts.character1);
        {
            vm.expectRevert(Errors.RequirementNotMet.selector);
            bytes32[] memory proof = new bytes32[](0);

            deployments.items.obtainItems(claimableItemId, 1, proof);
        }

        vm.stopPrank();
    }

    function testInvalidTreeNot() public {
        vm.startPrank(accounts.gameMaster);
        //////////////////////////////
        {
            uint256 _itemId1 = deployments.items.createItemType(
                createNewItem(false, false, bytes32(0), 1, createEmptyRequiredAssets())
            );

            uint256 _itemId2 = deployments.items.createItemType(
                createNewItem(false, false, bytes32(0), 1, createEmptyRequiredAssets())
            );

            // The following tree should fail
            //
            //                                 NOT
            //                 /                                  \
            //               OR                                   AND
            //              /   \                                /   \
            // (100 of item1)   (200 of item2)          (1000 exp)   NOT
            //                                                         \
            //                                                         (2000 exp)
            //
            RequirementNode memory itemOr;

            {
                Asset memory assetItem1 = Asset(Category.ERC1155, address(deployments.items), _itemId1, 100);
                Asset memory assetItem2 = Asset(Category.ERC1155, address(deployments.items), _itemId2, 200);

                RequirementNode memory item1 =
                    RequirementNode({operator: 0, asset: assetItem1, children: new RequirementNode[](0)});

                RequirementNode memory item2 =
                    RequirementNode({operator: 0, asset: assetItem2, children: new RequirementNode[](0)});

                itemOr = RequirementNode({
                    operator: 2,
                    asset: Asset(Category.ERC20, address(0), 0, 0),
                    children: new RequirementNode[](2)
                });

                itemOr.children[0] = item1;
                itemOr.children[1] = item2;
            }

            RequirementNode memory expRange;

            {
                Asset memory assetExpMin = Asset(Category.ERC20, address(deployments.experience), 0, 1000);
                Asset memory assetExpMax = Asset(Category.ERC20, address(deployments.experience), 0, 2000);

                RequirementNode memory notExpMax =
                    RequirementNode({operator: 3, asset: assetExpMax, children: new RequirementNode[](0)});

                RequirementNode memory minExp =
                    RequirementNode({operator: 0, asset: assetExpMin, children: new RequirementNode[](0)});

                expRange = RequirementNode({
                    operator: 1,
                    asset: Asset(Category.ERC20, address(0), 0, 0),
                    children: new RequirementNode[](2)
                });

                expRange.children[0] = minExp;
                expRange.children[1] = notExpMax;
            }

            RequirementNode memory and = RequirementNode({
                operator: 3,
                asset: Asset(Category.ERC20, address(0), 0, 0),
                children: new RequirementNode[](2)
            });

            and.children[0] = itemOr;
            and.children[1] = expRange;

            bytes memory requiredAssets = RequirementsTree.encode(and);

            vm.expectRevert(Errors.InvalidNotOperator.selector);
            deployments.items.createItemType(createNewItem(false, false, bytes32(0), 1, requiredAssets));
        }
        vm.stopPrank();
    }

    function testInvalidTreeOr() public {
        vm.startPrank(accounts.gameMaster);
        //////////////////////////////////////////////////
        {
            uint256 _itemId1 = deployments.items.createItemType(
                createNewItem(false, false, bytes32(0), 1, createEmptyRequiredAssets())
            );

            uint256 _itemId2 = deployments.items.createItemType(
                createNewItem(false, false, bytes32(0), 1, createEmptyRequiredAssets())
            );

            // The following tree should fail
            //
            //                                 AND
            //                 /                                  \
            //               OR                                   AND
            //              /   \                                /   \
            // (100 of item1)   (200 of item2)          (1000 exp)    OR
            //                                                         \
            //                                                         (2000 exp)
            //
            RequirementNode memory itemOr;

            {
                Asset memory assetItem1 = Asset(Category.ERC1155, address(deployments.items), _itemId1, 100);
                Asset memory assetItem2 = Asset(Category.ERC1155, address(deployments.items), _itemId2, 200);

                RequirementNode memory item1 =
                    RequirementNode({operator: 0, asset: assetItem1, children: new RequirementNode[](0)});

                RequirementNode memory item2 =
                    RequirementNode({operator: 0, asset: assetItem2, children: new RequirementNode[](0)});

                itemOr = RequirementNode({
                    operator: 2,
                    asset: Asset(Category.ERC20, address(0), 0, 0),
                    children: new RequirementNode[](2)
                });

                itemOr.children[0] = item1;
                itemOr.children[1] = item2;
            }

            RequirementNode memory expRange;

            {
                Asset memory assetExpMin = Asset(Category.ERC20, address(deployments.experience), 0, 1000);
                Asset memory assetExpMax = Asset(Category.ERC20, address(deployments.experience), 0, 2000);

                RequirementNode memory notExpMax =
                    RequirementNode({operator: 2, asset: assetExpMax, children: new RequirementNode[](0)});

                RequirementNode memory minExp =
                    RequirementNode({operator: 0, asset: assetExpMin, children: new RequirementNode[](0)});

                expRange = RequirementNode({
                    operator: 1,
                    asset: Asset(Category.ERC20, address(0), 0, 0),
                    children: new RequirementNode[](2)
                });

                expRange.children[0] = minExp;
                expRange.children[1] = notExpMax;
            }

            RequirementNode memory and = RequirementNode({
                operator: 1,
                asset: Asset(Category.ERC20, address(0), 0, 0),
                children: new RequirementNode[](2)
            });

            and.children[0] = itemOr;
            and.children[1] = expRange;

            bytes memory requiredAssets = RequirementsTree.encode(and);

            vm.expectRevert(Errors.InvalidOrOperator.selector);
            deployments.items.createItemType(createNewItem(false, false, bytes32(0), 1, requiredAssets));
        }
        vm.stopPrank();
    }

    function testInvalidTreeAnd() public {
        vm.startPrank(accounts.gameMaster);
        //////////////////////////////////////////////////
        {
            uint256 _itemId1 = deployments.items.createItemType(
                createNewItem(false, false, bytes32(0), 1, createEmptyRequiredAssets())
            );

            // The following tree should fail
            //
            //                                 AND
            //                 /                                  \
            //               AND                                   AND
            //              /                                     /   \
            // (100 of item1)                            (1000 exp)    NOT
            //                                                         \
            //                                                         (2000 exp)
            //
            RequirementNode memory itemOr;

            {
                Asset memory assetItem1 = Asset(Category.ERC1155, address(deployments.items), _itemId1, 100);

                RequirementNode memory item1 =
                    RequirementNode({operator: 0, asset: assetItem1, children: new RequirementNode[](0)});

                itemOr = RequirementNode({
                    operator: 1,
                    asset: Asset(Category.ERC20, address(0), 0, 0),
                    children: new RequirementNode[](1)
                });

                itemOr.children[0] = item1;
            }

            RequirementNode memory expRange;

            {
                Asset memory assetExpMin = Asset(Category.ERC20, address(deployments.experience), 0, 1000);
                Asset memory assetExpMax = Asset(Category.ERC20, address(deployments.experience), 0, 2000);

                RequirementNode memory notExpMax =
                    RequirementNode({operator: 3, asset: assetExpMax, children: new RequirementNode[](0)});

                RequirementNode memory minExp =
                    RequirementNode({operator: 0, asset: assetExpMin, children: new RequirementNode[](0)});

                expRange = RequirementNode({
                    operator: 1,
                    asset: Asset(Category.ERC20, address(0), 0, 0),
                    children: new RequirementNode[](2)
                });

                expRange.children[0] = minExp;
                expRange.children[1] = notExpMax;
            }

            RequirementNode memory and = RequirementNode({
                operator: 1,
                asset: Asset(Category.ERC20, address(0), 0, 0),
                children: new RequirementNode[](2)
            });

            and.children[0] = itemOr;
            and.children[1] = expRange;

            bytes memory requiredAssets = RequirementsTree.encode(and);

            vm.expectRevert(Errors.InvalidAndOperator.selector);
            deployments.items.createItemType(createNewItem(false, false, bytes32(0), 1, requiredAssets));
        }
        //////////////////////////////

        vm.stopPrank();
    }

    function testUpdateClaimableItemRequirements() public {
        assertEq(itemsData.itemIdClaimable, 1, "incorrect item ID");
        Item memory returnedItem = deployments.items.getItem(itemsData.itemIdClaimable);
        bytes memory itemRequirements = deployments.itemsManager.getClaimRequirements(itemsData.itemIdClaimable);
        RequirementNode memory node = RequirementsTree.decode(itemRequirements);

        assertEq(node.operator, 0, "incorrect operator");
        assertEq(node.children.length, 0, "incorrect number of children");
        Asset memory asset = node.asset;
        assertEq(uint8(asset.category), uint8(Category.ERC20), "incorrect asset category");
        assertEq(asset.assetAddress, address(deployments.experience), "incorrect asset address");
        assertEq(asset.id, 0, "incorrect asset ID");
        assertEq(asset.amount, 100, "incorrect amount");

        // set new requirements
        RequirementNode memory expRange;

        {
            Asset memory assetExpMin = Asset(Category.ERC20, address(deployments.experience), 0, 3000);
            Asset memory assetExpMax = Asset(Category.ERC20, address(deployments.experience), 0, 4000);

            RequirementNode memory notExpMax =
                RequirementNode({operator: 3, asset: assetExpMax, children: new RequirementNode[](0)});

            RequirementNode memory minExp =
                RequirementNode({operator: 0, asset: assetExpMin, children: new RequirementNode[](0)});

            expRange = RequirementNode({
                operator: 1,
                asset: Asset(Category.ERC20, address(0), 0, 0),
                children: new RequirementNode[](2)
            });

            expRange.children[0] = minExp;
            expRange.children[1] = notExpMax;
        }

        bytes memory requiredAssets = RequirementsTree.encode(expRange);

        //prank
        vm.prank(accounts.gameMaster);
        deployments.items.setClaimRequirements(itemsData.itemIdClaimable, requiredAssets);

        itemRequirements = deployments.itemsManager.getClaimRequirements(itemsData.itemIdClaimable);
        node = RequirementsTree.decode(itemRequirements);

        assertEq(node.operator, 1, "incorrect operator");
        assertEq(node.children.length, 2, "incorrect number of children");
        asset = node.asset;
        assertEq(uint8(asset.category), uint8(Category.ERC20), "incorrect asset category");
        assertEq(asset.assetAddress, address(0), "incorrect asset address");
        assertEq(asset.id, 0, "incorrect asset ID");
        assertEq(asset.amount, 0, "incorrect amount");

        assertEq(node.children[0].operator, 0, "incorrect operator");
        assertEq(node.children[0].children.length, 0, "incorrect number of children");
        asset = node.children[0].asset;
        assertEq(uint8(asset.category), uint8(Category.ERC20), "incorrect asset category");
        assertEq(asset.assetAddress, address(deployments.experience), "incorrect asset address");
        assertEq(asset.id, 0, "incorrect asset ID");
        assertEq(asset.amount, 3000, "incorrect amount");

        assertEq(node.children[1].operator, 3, "incorrect operator");
        assertEq(node.children[1].children.length, 0, "incorrect number of children");
        asset = node.children[1].asset;
        assertEq(uint8(asset.category), uint8(Category.ERC20), "incorrect asset category");
        assertEq(asset.assetAddress, address(deployments.experience), "incorrect asset address");
        assertEq(asset.id, 0, "incorrect asset ID");
        assertEq(asset.amount, 4000, "incorrect amount");
    }

    function testUpdateCraftableItemRequirements() public {
        Item memory returnedItem = deployments.items.getItem(itemsData.itemIdCraftable);
        bytes memory itemRequirements = deployments.itemsManager.getCraftRequirements(itemsData.itemIdCraftable);
        CraftItem[] memory craftRequirements = abi.decode(itemRequirements, (CraftItem[]));

        assertEq(itemsData.itemIdCraftable, 2, "incorrect item ID");
        assertEq(craftRequirements.length, 1, "incorrect number of craft requirements");
        assertEq(craftRequirements[0].amount, 1, "incorrect amount");
        assertEq(craftRequirements[0].itemId, itemsData.itemIdSoulbound, "incorrect item ID");

        // set new requirements

        CraftItem[] memory requirements = new CraftItem[](2);
        requirements[0] = CraftItem(itemsData.itemIdSoulbound, 1);
        requirements[1] = CraftItem(itemsData.itemIdClaimable, 1);

        bytes memory requiredAssets = abi.encode(requirements);

        //prank
        vm.prank(accounts.gameMaster);
        deployments.items.setCraftRequirements(itemsData.itemIdCraftable, requiredAssets);

        itemRequirements = deployments.itemsManager.getCraftRequirements(itemsData.itemIdCraftable);
        craftRequirements = abi.decode(itemRequirements, (CraftItem[]));

        assertEq(craftRequirements.length, 2, "incorrect number of craft requirements");
        assertEq(craftRequirements[0].amount, 1, "incorrect amount");
        assertEq(craftRequirements[0].itemId, itemsData.itemIdSoulbound, "incorrect item ID");
        assertEq(craftRequirements[1].amount, 1, "incorrect amount");
        assertEq(craftRequirements[1].itemId, itemsData.itemIdClaimable, "incorrect item ID");

        requirements[1] = CraftItem(itemsData.itemIdCraftable, 1);
        requirements[0] = CraftItem(itemsData.itemIdSoulbound, 2);

        bytes memory requiredAssets2 = abi.encode(requirements);

        //prank
        vm.prank(accounts.gameMaster);
        vm.expectRevert(Errors.CraftItemError.selector);
        deployments.items.setCraftRequirements(itemsData.itemIdCraftable, requiredAssets2);
    }

    function testSimpleRequirementsClaimWithItem1() public {
        uint256 claimableItemId = createSimpleClaimableItem();

        vm.startPrank(accounts.gameMaster);
        {
            address[] memory players = new address[](1);
            players[0] = accounts.character1;
            uint256[][] memory itemIds = new uint256[][](1);
            itemIds[0] = new uint256[](1);
            itemIds[0][0] = claimableItemId - 1;
            uint256[][] memory amounts = new uint256[][](1);
            amounts[0] = new uint256[](1);
            amounts[0][0] = 100;

            deployments.items.dropLoot(players, itemIds, amounts);
        }
        vm.stopPrank();

        assertEq(deployments.items.balanceOf(accounts.character1, claimableItemId - 1), 100, "item not dropped");
        assertEq(deployments.items.balanceOf(accounts.character1, claimableItemId), 0, "item already claimed");

        vm.startPrank(accounts.character1);
        {
            bytes32[] memory proof = new bytes32[](0);

            deployments.items.obtainItems(claimableItemId, 1, proof);
        }

        vm.stopPrank();
        assertEq(deployments.items.balanceOf(accounts.character1, claimableItemId), 1, "item not claimed");
    }
}
