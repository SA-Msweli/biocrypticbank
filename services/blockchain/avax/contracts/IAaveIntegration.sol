// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Interface for the AaveIntegration contract
// This defines the functions that AvalancheCoreBanking expects to call on the AaveIntegration contract.
interface IAaveIntegration {
    function supplyAsset(address asset, uint256 amount, address onBehalfOf) external;
    function withdrawAsset(address asset, uint256 amount, address to) external;
}