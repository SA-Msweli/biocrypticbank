// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IPool} from "@aave/core-v3/contracts/interfaces/IPool.sol";


/**
 * @title AaveIntegration
 * @dev This contract acts as an intermediary for BioCrypticBank's AvalancheCoreBanking
 * to interact with the Aave V3 lending protocol on Avalanche.
 * It handles the logic for supplying assets to Aave and withdrawing them.
 */
contract AaveIntegration is Ownable {

    IPool public immutable AAVE_POOL;

    event AssetSupplied(address indexed asset, uint256 amount, address indexed onBehalfOf);
    event AssetWithdrawn(address indexed asset, uint256 amount, address indexed to);

    /**
     * @dev Constructor sets the immutable Aave Pool address.
     * @param _aavePoolAddress The address of the Aave V3 Pool contract.
     */
    constructor(address _aavePoolAddress) Ownable(msg.sender) {
        require(_aavePoolAddress != address(0), "Aave Pool address cannot be zero.");
        AAVE_POOL = IPool(_aavePoolAddress);
    }

    /**
     * @dev Allows this contract's owner (which would be the AvalancheCoreBanking contract)
     * to supply an asset to Aave.
     * The tokens must first be transferred to this AaveIntegration contract.
     * This contract will then approve the Aave Pool and call its `supply` function.
     * @param asset The address of the ERC20 token to supply (e.g., USDC, WETH).
     * @param amount The amount of tokens to supply.
     * @param onBehalfOf The address that will be recorded as the depositor and receive the aTokens.
     * This is typically the address of the AvalancheCoreBanking contract itself.
     */
    function supplyAsset(address asset, uint256 amount, address onBehalfOf) external onlyOwner {
        require(asset != address(0), "Asset address cannot be zero.");
        require(amount > 0, "Amount must be greater than 0.");
        require(onBehalfOf != address(0), "OnBehalfOf address cannot be zero.");


        (bool success, ) = address(asset).call(abi.encodeWithSelector(IERC20.approve.selector, address(AAVE_POOL), amount));
        require(success, "Token approval failed.");


        AAVE_POOL.supply(asset, amount, onBehalfOf, 0);

        emit AssetSupplied(asset, amount, onBehalfOf);
    }

    /**
     * @dev Allows this contract's owner (AvalancheCoreBanking) to withdraw assets from Aave.
     * The withdrawn assets will be transferred back to the `to` address, which should be
     * the AvalancheCoreBanking contract.
     * @param asset The address of the ERC20 token to withdraw.
     * @param amount The amount of tokens to withdraw. Use `type(uint256).max` to withdraw all.
     * @param to The address that will receive the withdrawn assets (e.g., AvalancheCoreBanking).
     */
    function withdrawAsset(address asset, uint256 amount, address to) external onlyOwner {
        require(asset != address(0), "Asset address cannot be zero.");
        require(amount > 0, "Amount must be greater than 0.");
        require(to != address(0), "Recipient address cannot be zero.");


        AAVE_POOL.withdraw(asset, amount, to);

        emit AssetWithdrawn(asset, amount, to);
    }

    /**
     * @dev Function to retrieve any ERC20 tokens accidentally sent to this contract
     */
    function recoverERC20(address tokenAddress, uint256 amount) external onlyOwner {
        require(tokenAddress != address(0), "Token address cannot be zero.");
        require(amount > 0, "Amount must be greater than 0.");

        (bool success, ) = address(tokenAddress).call(abi.encodeWithSelector(IERC20.transfer.selector, owner(), amount));
        require(success, "Recovery transfer failed.");
    }

    /**
     * @dev Fallback function to accept native token (AVAX)
     */
    receive() external payable {}
}
