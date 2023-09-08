// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";
import "openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import "openzeppelin-contracts/contracts/interfaces/IERC1271.sol";
import "openzeppelin-contracts/contracts/utils/cryptography/SignatureChecker.sol";
import "openzeppelin-contracts/contracts/token/ERC1155/utils/ERC1155Holder.sol";

import "./interfaces/IERC6551Account.sol";
import "./lib/ERC6551AccountLib.sol";

/**
 * @title NPC Acount
 * @author Mr DeadCe11
 * @notice This is a simple ERC6551 account implementation that can hold ERC1155 tokens
 */

contract CharacterAccount is IERC165, IERC1271, IERC6551Account, ERC1155Holder {
    uint256 public nonce;

    receive() external payable {}


    function supportsInterface(bytes4 interfaceId) public pure override(ERC1155Receiver, IERC165) returns (bool) {
        return (interfaceId == type(IERC165).interfaceId || interfaceId == type(IERC6551Account).interfaceId);
    }

    function executeCall(address to, uint256 value, bytes calldata data)
        external
        payable
        returns (bytes memory result)
    {
        require(msg.sender == owner(), "Not token owner");

        ++nonce;

        emit TransactionExecuted(to, value, data);

        bool success;
        (success, result) = to.call{value: value}(data);

        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
    }

    function token() external view returns (uint256, address, uint256) {
        return ERC6551AccountLib.token();
    }

    function isValidSignature(bytes32 hash, bytes memory signature) external view returns (bytes4 magicValue) {
        bool isValid = SignatureChecker.isValidSignatureNow(owner(), hash, signature);

        if (isValid) {
            return IERC1271.isValidSignature.selector;
        }

        return "";
    }

    function owner() public view returns (address) {
        (uint256 chainId, address tokenContract, uint256 tokenId) = this.token();
        if (chainId != block.chainid) return address(0);

        return IERC721(tokenContract).ownerOf(tokenId);
    }
}
