// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC165} from "openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";
import {IERC721} from "openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import {IERC1271} from "openzeppelin-contracts/contracts/interfaces/IERC1271.sol";
import {SignatureChecker} from "openzeppelin-contracts/contracts/utils/cryptography/SignatureChecker.sol";
import {
    ERC1155Holder,
    ERC1155Receiver,
    IERC1155Receiver
} from "openzeppelin-contracts/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import {Executor, Enum} from "safe-contracts/contracts/base/Executor.sol";

import {IERC6551Account} from "./interfaces/IERC6551Account.sol";
import {IERC6551Executable} from "./interfaces/IERC6551Executable.sol";

/**
 * @title NPC Acount
 * @author Mr DeadCe11
 * @notice This is a simple ERC6551 account implementation that can hold ERC1155 tokens
 */

contract CharacterAccount is IERC165, IERC1271, IERC6551Account, IERC6551Executable, ERC1155Holder, Executor {
    uint256 public state;

    event Executed(bool success);

    receive() external payable {}

    function execute(address to, uint256 value, bytes calldata data, uint256 operation)
        external
        payable
        returns (bytes memory result)
    {
        require(_isValidSigner(msg.sender), "Invalid signer");
        require(operation > 1, "Invalid Operation");

        ++state;

        bool success;
        success = execute(to, value, data, Enum.Operation(operation), type(uint256).max);

        // solhint-disable-next-line no-inline-assembly
        assembly {
            // Load free memory location
            let ptr := mload(0x40)
            // We allocate memory for the return data by setting the free memory location to
            // current free memory location + data size + 32 bytes for data size value
            mstore(0x40, add(ptr, add(returndatasize(), 0x20)))
            // Store the size
            mstore(ptr, returndatasize())
            // Store the data
            returndatacopy(add(ptr, 0x20), 0, returndatasize())
            // Point the return data to the correct memory location
            result := ptr
        }

        emit Executed(success);
    }

    function isValidSigner(address signer, bytes calldata) external view returns (bytes4) {
        if (_isValidSigner(signer)) {
            return IERC6551Account.isValidSigner.selector;
        }

        return bytes4(0);
    }

    function isValidSignature(bytes32 hash, bytes memory signature) external view returns (bytes4 magicValue) {
        bool isValid = SignatureChecker.isValidSignatureNow(owner(), hash, signature);

        if (isValid) {
            return IERC1271.isValidSignature.selector;
        }

        return "";
    }

    function token() public view returns (uint256, address, uint256) {
        bytes memory footer = new bytes(0x60);

        // solhint-disable-next-line no-inline-assembly
        assembly {
            extcodecopy(address(), add(footer, 0x20), 0x4d, 0x60)
        }

        return abi.decode(footer, (uint256, address, uint256));
    }

    function owner() public view returns (address) {
        (uint256 chainId, address tokenContract, uint256 tokenId) = token();
        if (chainId != block.chainid) return address(0);

        return IERC721(tokenContract).ownerOf(tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public pure override(ERC1155Receiver, IERC165) returns (bool) {
        return (
            interfaceId == type(IERC165).interfaceId || interfaceId == type(IERC6551Account).interfaceId
                || interfaceId == type(IERC6551Executable).interfaceId || interfaceId == type(IERC1155Receiver).interfaceId
        );
    }

    function _isValidSigner(address signer) internal view returns (bool) {
        return signer == owner();
    }
}
