// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {IPool, IPoolAddressesProvider} from "@aave/core-v3/contracts/interfaces/IPool.sol";

// Interface for the AaveIntegration contract for external calls
interface IAaveIntegration {
    function supplyAsset(address asset, uint256 amount) external;
    function withdrawAsset(address asset, uint256 amount, address to) external;
    function getUserSuppliedBalance(address user, address asset) external view returns (uint256);
}

/**
 * @title AaveIntegration
 * @dev This contract provides a simplified interface for interacting with Aave V3 on Avalanche C-Chain.
 * It allows users (or other contracts like AvalancheCoreBanking) to supply (deposit) and withdraw assets from Aave's lending pool.
 * For production use, a more robust error handling, reentrancy guards, and gas optimizations would be necessary.
 * Users must first approve this contract to spend their ERC20 tokens before calling supply.
 */
contract AaveIntegration is Ownable, IAaveIntegration {
    IPoolAddressesProvider public immutable POOL_ADDRESSES_PROVIDER;
    IPool public immutable AAVE_POOL;

    event AssetSupplied(address indexed user, address indexed asset, uint256 amount);
    event AssetWithdrawn(address indexed user, address indexed asset, uint256 amount);

    /**
     * @dev Constructor sets the Aave Pool Addresses Provider.
     * @param _poolAddressesProvider Address of the Aave Pool Addresses Provider on Avalanche.
     */
    constructor(address _poolAddressesProvider) Ownable(msg.sender) {
        POOL_ADDRESSES_PROVIDER = IPoolAddressesProvider(_poolAddressesProvider);
        AAVE_POOL = IPool(POOL_ADDRESSES_PROVIDER.getPool());
    }

    /**
     * @dev Allows a user or another contract (like AvalancheCoreBanking) to supply ERC20 tokens to the Aave V3 pool.
     * This contract must have approval to spend the `asset` token from the caller (or the forwarding contract).
     * @param asset The address of the ERC20 token to supply (e.g., USDC.e, DAI.e).
     * @param amount The amount of the token to supply.
     */
    function supplyAsset(address asset, uint256 amount) external override {
        // Ensure this contract has enough allowance from the source (e.g., AvalancheCoreBanking or direct user)
        // If called directly by a user, user must approve this contract.
        // If called by AvalancheCoreBanking, Core Banking contract already transferred funds here.
        // We still need to approve Aave Pool to pull from *this* contract.

        // Approve the Aave Pool contract to pull tokens from this contract
        IERC20(asset).approve(address(AAVE_POOL), amount);

        // Supply the asset to Aave. The `msg.sender` of this call (which could be the AvalancheCoreBanking contract)
        // is recorded as the on-behalf-of address for Aave accounting.
        AAVE_POOL.supply(asset, amount, msg.sender, 0);

        emit AssetSupplied(msg.sender, asset, amount);
    }

    /**
     * @dev Allows a user or another contract to withdraw previously supplied ERC20 tokens from the Aave V3 pool.
     * @param asset The address of the ERC20 token to withdraw.
     * @param amount The amount of the token to withdraw. Use type(uint256).max to withdraw all.
     * @param to The address to send the withdrawn assets to (e.g., the user or the AvalancheCoreBanking contract).
     */
    function withdrawAsset(address asset, uint256 amount, address to) external override {
        require(amount > 0, "Amount must be greater than 0");
        require(to != address(0), "Recipient address cannot be zero.");

        // Withdraw the asset from Aave. Aave will send the tokens directly to the `to` address.
        AAVE_POOL.withdraw(asset, amount, to);

        emit AssetWithdrawn(msg.sender, asset, amount);
    }

    /**
     * @dev Retrieves the user's balance of a specific asset within the Aave pool.
     * This is the amount of aTokens the user holds, representing their supplied liquidity.
     * @param user The address of the user.
     * @param asset The address of the underlying asset (e.g., USDC.e, DAI.e).
     * @return The balance of the asset supplied by the user to Aave.
     */
    function getUserSuppliedBalance(address user, address asset) external view override returns (uint256) {
        // Aave's getReserveData function provides details including aToken address
        // The aToken represents the supplied asset.
        (
            , // configuration
            , // liquidityIndex
            , // variableBorrowIndex
            , // currentLiquidityRate
            , // currentVariableBorrowRate
            , // currentStableBorrowRate
            , // lastUpdateTimestamp
            address aTokenAddress, // aToken address
            , // stableDebtTokenAddress
            , // variableDebtTokenAddress
            , // interestRateStrategyAddress
            , // id
        ) = AAVE_POOL.getReserveData(asset);

        return IERC20(aTokenAddress).balanceOf(user);
    }

    /**
     * @dev Allows the contract owner to recover any ERC20 tokens accidentally sent to this contract.
     * This is crucial to prevent funds from being permanently locked.
     * @param tokenAddress The address of the ERC20 token to recover.
     * @param amount The amount of tokens to recover.
     */
    function recoverERC20(address tokenAddress, uint256 amount) external onlyOwner {
        IERC20(tokenAddress).transfer(owner(), amount);
    }

    /**
     * @dev Allows the contract owner to recover native gas token (AVAX on EVM) accidentally sent to this contract.
     */
    function recoverNativeToken() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
}
