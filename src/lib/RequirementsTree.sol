// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./Structs.sol";
import "./Errors.sol";

library RequirementsTree {
    function decodeToStorage(bytes memory requirementTree, RequirementNode storage root) internal {
        bytes[] memory nodes;

        (root.operator, root.asset, nodes) = abi.decode(requirementTree, (uint8, Asset, bytes[]));

        uint256 nodelength = nodes.length;

        for (uint256 i; i < nodelength; i++) {
            root.children.push();
            // root.children[i] = decode(node);
            decodeToStorage(nodes[i], root.children[i]);
        }
    }

    function encodeFromStorage(RequirementNode storage node) internal view returns (bytes memory requirementTree) {
        bytes[] memory nodes = new bytes[](node.children.length);
        for (uint256 i; i < node.children.length; i++) {
            nodes[i] = encodeFromStorage(node.children[i]);
        }
        return abi.encode(node.operator, node.asset, nodes);
    }

    function validateTreeInStorage(RequirementNode storage node) internal view {
        if (node.operator == 0) {
            if (node.children.length != 0 || node.asset.assetAddress == address(0)) {
                revert Errors.InvalidNilOperator();
            }
        } else if (node.operator == 1) {
            if (node.children.length < 1 || node.asset.assetAddress != address(0)) {
                revert Errors.InvalidAndOperator();
            }
        } else if (node.operator == 2) {
            if (node.children.length < 1 || node.asset.assetAddress != address(0)) {
                revert Errors.InvalidOrOperator();
            }
        } else if (node.operator == 3) {
            if (
                !(
                    (node.children.length == 1 && node.asset.assetAddress == address(0))
                        || (node.children.length == 0 && node.asset.assetAddress != address(0))
                )
            ) {
                revert Errors.InvalidNotOperator();
            }
        } else {
            revert Errors.InvalidOperator();
        }
        for (uint256 i; i < node.children.length; i++) {
            validateTree(node.children[i]);
        }
    }

    function decode(bytes memory requirementTree) internal pure returns (RequirementNode memory) {
        uint8 operator;
        Asset memory asset;
        bytes[] memory nodes;

        (operator, asset, nodes) = abi.decode(requirementTree, (uint8, Asset, bytes[]));
        uint256 nodelength = nodes.length;

        RequirementNode memory root =
            RequirementNode({operator: operator, children: new RequirementNode[](nodelength), asset: asset});

        for (uint256 i; i < nodelength; i++) {
            root.children[i] = decode(nodes[i]);
        }

        return root;
    }

    function encode(RequirementNode memory node) internal pure returns (bytes memory requirementTree) {
        bytes[] memory nodes = new bytes[](node.children.length);
        for (uint256 i; i < node.children.length; i++) {
            nodes[i] = encode(node.children[i]);
        }
        return abi.encode(node.operator, node.asset, nodes);
    }

    function validateTree(RequirementNode memory node) internal pure {
        if (node.operator == 0) {
            if (node.children.length != 0 || node.asset.assetAddress == address(0)) {
                revert Errors.InvalidNilOperator();
            }
        } else if (node.operator == 1) {
            if (node.children.length < 2 || node.asset.assetAddress != address(0)) {
                revert Errors.InvalidAndOperator();
            }
        } else if (node.operator == 2) {
            if (node.children.length < 2 || node.asset.assetAddress != address(0)) {
                revert Errors.InvalidOrOperator();
            }
        } else if (node.operator == 3) {
            if (
                !(
                    (node.children.length == 1 && node.asset.assetAddress == address(0))
                        || (node.children.length == 0 && node.asset.assetAddress != address(0))
                )
            ) {
                revert Errors.InvalidNotOperator();
            }
        } else {
            revert Errors.InvalidOperator();
        }
        for (uint256 i; i < node.children.length; i++) {
            validateTree(node.children[i]);
        }
    }
}
