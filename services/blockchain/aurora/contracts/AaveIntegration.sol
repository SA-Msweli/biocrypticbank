// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@aave/core-v3/contracts/interfaces/IPool.sol";
import "@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol";
import "./IProtocolDataProvider.sol";

contract AaveIntegration {
    IPool public immutable pool;
    IProtocolDataProvider public immutable dataProvider;

constructor(address poolAddressProvider, address dataProviderAddress) {
    pool = IPool(IPoolAddressesProvider(poolAddressProvider).getPool());
    dataProvider = IProtocolDataProvider(dataProviderAddress);
}


    // ===== Deposit collateral into Aave =====
    function depositCollateral(address asset, uint256 amount) external {
        IERC20(asset).transferFrom(msg.sender, address(this), amount);
        IERC20(asset).approve(address(pool), amount);
        pool.supply(asset, amount, msg.sender, 0);
    }

    // ===== Borrow asset from Aave =====
    function borrowAsset(address asset, uint256 amount, uint8 interestRateMode) external {
        pool.borrow(asset, amount, interestRateMode, 0, msg.sender);
    }

    // ===== Repay loan to Aave =====
    function repayAsset(address asset, uint256 amount, uint8 interestRateMode) external {
        IERC20(asset).transferFrom(msg.sender, address(this), amount);
        IERC20(asset).approve(address(pool), amount);
        pool.repay(asset, amount, interestRateMode, msg.sender);
    }

    // ===== Withdraw collateral from Aave =====
    function withdrawCollateral(address asset, uint256 amount) external {
        pool.withdraw(asset, amount, msg.sender);
    }

    // ===== View user’s account health =====
    function getUserAccountData(address user)
        external
        view
        returns (
            uint256 totalCollateralETH,
            uint256 totalDebtETH,
            uint256 availableBorrowsETH,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        )
    {
        return pool.getUserAccountData(user);
    }

    // ===== View user reserve data (aToken, debt) =====
    function getUserReserveData(address asset, address user)
        external
        view
        returns (
            uint256 currentATokenBalance,
            uint256 currentStableDebt,
            uint256 currentVariableDebt,
            uint256 principalStableDebt,
            uint256 scaledVariableDebt,
            uint256 stableBorrowRate,
            uint256 liquidityRate,
            uint40 stableRateLastUpdated,
            bool usageAsCollateralEnabled
        )
    {
        return dataProvider.getUserReserveData(asset, user);
    }
}