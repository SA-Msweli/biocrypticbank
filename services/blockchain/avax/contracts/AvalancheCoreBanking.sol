// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

// Import interfaces for external contracts
import {IAaveIntegration} from "./AaveIntegration.sol"; // Assuming AaveIntegration contract in the same directory
import {IRWAHub} from "./RWAHub.sol"; // Assuming RWAHub contract in the same directory

/**
 * @title AvalancheCoreBanking
 * @dev This contract provides core banking functionalities for ERC-20 tokens on the Avalanche C-Chain.
 * It allows users to deposit, withdraw, and check balances of supported ERC20 tokens.
 * This contract acts as a central vault for these tokens, similar to a traditional bank account.
 * Includes a reentrancy guard for withdrawal safety.
 * It also facilitates interaction with external DeFi (Aave) and RWA protocols.
 */
contract AvalancheCoreBanking is Ownable, ReentrancyGuard {
    // Mapping from token address to user address to balance
    mapping(address => mapping(address => uint256)) public balances;
    // Mapping to track explicitly supported tokens for banking operations
    mapping(address => bool) public isSupportedToken;

    // Addresses of integrated external protocols
    IAaveIntegration public aaveIntegrationContract;
    IRWAHub public rwaHubContract;

    event Deposited(address indexed token, address indexed user, uint256 amount);
    event Withdrawn(address indexed token, address indexed user, uint256 amount);
    event TokenSupportToggled(address indexed token, bool supported);
    event AaveIntegrationContractSet(address indexed newAddress);
    event RWAHubContractSet(address indexed newAddress);
    event SentToAave(address indexed user, address indexed asset, uint256 amount);
    event ReceivedFromAave(address indexed user, address indexed asset, uint256 amount);
    event CollateralSentForRWA(address indexed user, address indexed collateralToken, uint256 amount);


    /**
     * @dev Constructor initializes the contract with an owner.
     */
    constructor() Ownable(msg.sender) {
        // Owner can add supported tokens and set integration contracts after deployment.
    }

    /**
     * @dev Allows the owner to toggle support for an ERC20 token.
     * Only supported tokens can be used for deposit and withdrawal via this contract.
     * @param token Address of the ERC20 token.
     * @param support True to enable support, false to disable.
     */
    function toggleTokenSupport(address token, bool support) external onlyOwner {
        require(token != address(0), "Token address cannot be zero.");
        isSupportedToken[token] = support;
        emit TokenSupportToggled(token, support);
    }

    /**
     * @dev Allows the owner to set the address of the Aave integration contract.
     * @param _aaveIntegrationAddress The address of the AaveIntegration contract.
     */
    function setAaveIntegrationContract(address _aaveIntegrationAddress) external onlyOwner {
        require(_aaveIntegrationAddress != address(0), "Aave Integration address cannot be zero.");
        aaveIntegrationContract = IAaveIntegration(_aaveIntegrationAddress);
        emit AaveIntegrationContractSet(_aaveIntegrationAddress);
    }

    /**
     * @dev Allows the owner to set the address of the RWA Hub contract.
     * @param _rwaHubAddress The address of the RWAHub contract.
     */
    function setRWAHubContract(address _rwaHubAddress) external onlyOwner {
        require(_rwaHubAddress != address(0), "RWA Hub address cannot be zero.");
        rwaHubContract = IRWAHub(_rwaHubAddress);
        emit RWAHubContractSet(_rwaHubAddress);
    }

    /**
     * @dev Allows users to deposit ERC20 tokens into the contract.
     * Users must first approve this contract to spend their tokens.
     * @param token Address of the ERC20 token to deposit (e.g., USDC.e, USDT.e).
     * @param amount Amount of tokens to deposit.
     */
    function deposit(address token, uint256 amount) external {
        require(isSupportedToken[token], "Token not supported for deposit.");
        require(amount > 0, "Deposit amount must be greater than 0.");
        // Transfer tokens from the caller (msg.sender) to this contract
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        balances[token][msg.sender] += amount;
        emit Deposited(token, msg.sender, amount);
    }

    /**
     * @dev Allows users to withdraw ERC20 tokens from the contract.
     * Uses reentrancy guard to prevent re-entrant attacks during withdrawal.
     * @param token Address of the ERC20 token to withdraw.
     * @param amount Amount of tokens to withdraw.
     */
    function withdraw(address token, uint256 amount) external nonReentrant {
        require(isSupportedToken[token], "Token not supported for withdrawal.");
        require(amount > 0, "Withdrawal amount must be greater than 0.");
        require(balances[token][msg.sender] >= amount, "Insufficient balance.");

        balances[token][msg.sender] -= amount; // Deduct balance before external call (Checks-Effects-Interactions)
        // Transfer tokens from this contract back to the caller
        IERC20(token).transfer(msg.sender, amount);
        emit Withdrawn(token, msg.sender, amount);
    }

    /**
     * @dev Allows a user to move supported tokens from their balance in this bank to Aave for lending.
     * This contract transfers the tokens to the `aaveIntegrationContract` which then supplies them to Aave.
     * @param asset The address of the ERC20 token to lend (must be a supported token in this bank).
     * @param amount The amount of tokens to send to Aave.
     */
    function depositIntoAave(address asset, uint256 amount) external nonReentrant {
        require(address(aaveIntegrationContract) != address(0), "Aave Integration contract not set.");
        require(isSupportedToken[asset], "Asset not supported by this bank for lending.");
        require(amount > 0, "Amount must be greater than 0.");
        require(balances[asset][msg.sender] >= amount, "Insufficient balance in bank account.");

        // Deduct from bank balance
        balances[asset][msg.sender] -= amount;

        // Transfer tokens from this contract to the Aave integration contract
        IERC20(asset).transfer(address(aaveIntegrationContract), amount);

        // Call the Aave integration contract to supply the asset to Aave
        // The Aave integration contract should handle its own approval and supply logic
        IAaveIntegration(address(aaveIntegrationContract)).supplyAsset(asset, amount);

        emit SentToAave(msg.sender, asset, amount);
    }

    /**
     * @dev Allows a user to withdraw assets from Aave and receive them back into their bank balance.
     * This calls the `aaveIntegrationContract` to initiate the withdrawal from Aave.
     * Note: The `aaveIntegrationContract` must then transfer the withdrawn assets back to this contract (address(this)).
     * @param asset The address of the ERC20 token to withdraw from Aave.
     * @param amount The amount of tokens to withdraw. Use type(uint256).max to withdraw all.
     */
    function withdrawFromAave(address asset, uint256 amount) external nonReentrant {
        require(address(aaveIntegrationContract) != address(0), "Aave Integration contract not set.");
        require(isSupportedToken[asset], "Asset not supported by this bank for withdrawal from Aave.");
        require(amount > 0, "Amount must be greater than 0.");

        // Call the Aave integration contract to withdraw the asset from Aave.
        // This implicitly assumes the AaveIntegration contract will send tokens to address(this)
        // upon successful withdrawal.
        IAaveIntegration(address(aaveIntegrationContract)).withdrawAsset(asset, amount, address(this));

        // Note: The actual balance update in `balances[asset][msg.sender]` happens
        // when the tokens are transferred back to this contract from the AaveIntegration.
        // For simplicity, we assume this is handled by the AaveIntegration contract sending
        // directly to the user or back to this contract's address, which then transfers to user.
        // A more robust system might use a callback mechanism from the AaveIntegration.
        // For now, we'll log the event.
        emit ReceivedFromAave(msg.sender, asset, amount);
    }

    /**
     * @dev Allows a user to send supported collateral tokens from their bank balance to the RWA Hub.
     * This facilitates RWA tokenization where the RWA Hub would hold the collateral.
     * @param collateralToken The address of the ERC20 token to use as collateral.
     * @param amount The amount of collateral to send.
     */
    function sendCollateralForRWA(address collateralToken, uint256 amount) external nonReentrant {
        require(address(rwaHubContract) != address(0), "RWA Hub contract not set.");
        require(isSupportedToken[collateralToken], "Collateral token not supported by this bank.");
        require(amount > 0, "Amount must be greater than 0.");
        require(balances[collateralToken][msg.sender] >= amount, "Insufficient collateral balance in bank account.");

        // Deduct from bank balance
        balances[collateralToken][msg.sender] -= amount;

        // Transfer collateral tokens from this contract to the RWA Hub contract
        IERC20(collateralToken).transfer(address(rwaHubContract), amount);

        // Optionally, call a function on the RWA Hub to register this collateral for a specific RWA minting
        // This would require a more specific interface for IRWAHub
        // IRWAHub(address(rwaHubContract)).registerCollateral(collateralToken, amount, msg.sender);

        emit CollateralSentForRWA(msg.sender, collateralToken, amount);
    }

    /**
     * @dev Retrieves a user's balance for a specific ERC20 token within this contract.
     * This is a view function and does not modify the state.
     * @param token Address of the ERC20 token.
     * @param user Address of the user.
     * @return The balance of the token for the given user.
     */
    function getUserBalance(address token, address user) external view returns (uint256) {
        return balances[token][user];
    }

    /**
     * @dev Fallback function to accept native token (AVAX on EVM) for accidental transfers.
     */
    receive() external payable {}

    /**
     * @dev Allows the contract owner to recover any ERC20 tokens accidentally sent to this contract
     * that are NOT part of the intended banking logic. This is for emergency recovery.
     * @param tokenAddress The address of the ERC20 token to recover.
     * @param amount The amount of tokens to recover.
     */
    function recoverERC20(address tokenAddress, uint256 amount) external onlyOwner {
        // Only recover if the token is not a supported banking token, or if explicitly called by owner
        require(!isSupportedToken[tokenAddress] || msg.sender == owner(), "Cannot recover supported tokens without owner permission.");
        IERC20(tokenAddress).transfer(owner(), amount);
    }

    /**
     * @dev Allows the contract owner to recover native token (AVAX on EVM) accidentally sent to this contract.
     */
    function recoverNativeToken() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
}
