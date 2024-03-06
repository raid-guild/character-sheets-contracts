// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Class} from "../lib/Structs.sol";

interface IClasses {
    function setBaseURI(string memory _baseUri) external;

    function setURI(uint256 tokenId, string memory tokenURI) external;

    function claimClass(uint256 classId) external returns (bool);

    function updateClonesAddressStorage(address newClonesStorage) external;

    function createClassType(bytes calldata classData) external returns (uint256 tokenId);

    function assignClass(address character, uint256 classId) external;

    function revokeClass(address character, uint256 classId) external returns (bool success);

    function renounceClass(uint256 classId) external returns (bool success);
    function giveClassExp(address characterAccount, uint256 classId, uint256 amountOfExp) external;
    function revokeClassExp(address characterAccount, uint256 classId, uint256 amountOfExp) external;
    function getClassExp(address characterAccount, uint256 classId) external returns (uint256);
    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes memory data) external;

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) external;

    function getAllClasses() external view returns (Class[] memory);

    function getClass(uint256 classId) external view returns (Class memory);

    function supportsInterface(bytes4 interfaceId) external view returns (bool);

    function uri(uint256 tokenId) external view returns (string memory);

    function getBaseURI() external view returns (string memory);
}
