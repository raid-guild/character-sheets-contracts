// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC165} from "openzeppelin-contracts/utils/introspection/IERC165.sol";
import {IERC721} from "openzeppelin-contracts/token/ERC721/IERC721.sol";
import {IERC1271} from "openzeppelin-contracts/interfaces/IERC1271.sol";
import {SignatureChecker} from "openzeppelin-contracts/utils/cryptography/SignatureChecker.sol";
import {
    ERC1155Holder,
    ERC1155Receiver,
    IERC1155Receiver
} from "openzeppelin-contracts/token/ERC1155/utils/ERC1155Holder.sol";

import {IERC6551Account} from "./interfaces/IERC6551Account.sol";
import {IERC6551Executable} from "./interfaces/IERC6551Executable.sol";
import {CallUtils} from "./lib/CallUtils.sol";
import {Errors} from "./lib/Errors.sol";

/**
 * @title NPC Acount
 * @author Mr DeadCe11
 * @notice This is a simple ERC6551 account implementation that can hold ERC1155 tokens
 */

contract CharacterAccount is IERC165, IERC1271, IERC6551Account, IERC6551Executable, ERC1155Holder {
    uint256 public state;

    event Executed();

    receive() external payable {}

    function execute(address to, uint256 value, bytes calldata data, uint256 operation)
        external
        payable
        returns (bytes memory result)
    {
        if (!_isValidSigner(msg.sender)) {
            revert Errors.InvalidSigner();
        }

        ++state;

        bool success;

        if (operation == 0) {
            // solhint-disable-next-line avoid-low-level-calls
            (success, result) = to.call{value: value}(data);
        } else if (operation == 1) {
            // solhint-disable-next-line avoid-low-level-calls
            (success, result) = to.delegatecall(data);
        } else {
            revert Errors.InvalidOperation();
        }

        if (!success) {
            CallUtils.revertFromReturnedData(result);
        }

        emit Executed();
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
