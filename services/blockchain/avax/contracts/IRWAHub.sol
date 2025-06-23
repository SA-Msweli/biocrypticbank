// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IRWAHub
 * @dev Interface for the RWAHub contract.
 * Defines the external functions that other contracts (like AvalancheCoreBanking)
 * can call on the RWAHub. This promotes modularity and type safety.
 */
interface IRWAHub {
    function issueRWA(address to, string memory uri, string memory metadataURI) external returns (uint256);
    function transferFrom(address from, address to, uint256 tokenId) external;
    function toggleRWAStatus(uint256 tokenId, bool status) external;
    function getRWAStatus(uint256 tokenId) external view returns (bool);
    function getRWAInfo(uint256 assetId) external view returns (string memory name, uint256 value, address owner);
}
