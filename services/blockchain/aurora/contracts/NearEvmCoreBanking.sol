// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol"; // ADDED: Re-import ReentrancyGuard for safety

// Correct Aave V3 IPool interface import and usage
import {IPool} from "@aave/core-v3/contracts/interfaces/IPool.sol"; // Using IPool for Aave interactions

/**
 * @title NearEvmCoreBanking (Upgraded)
 * @dev Secure vault for managing ERC-20 tokens on Aurora with support for whitelisted tokens,
 * safe deposit logic, Aave yield integration, internal transfers, emergency pause, and recovery tools.
 * Includes Ownable2Step, Pausable, and ReentrancyGuard for robust security.
 */
contract NearEvmCoreBanking is Ownable2Step, Pausable, ReentrancyGuard { // ADDED: Inherit ReentrancyGuard
    mapping(address => mapping(address => uint256)) public balances;
    mapping(address => bool) public isSupportedToken;
    address[] public supportedTokens; // Stores list of supported tokens

    IPool public aavePool; // Changed to IPool for Aave V3
    address public aaveTreasury; // Address designated to receive Aave yields or manage collected interest

    event Deposited(address indexed token, address indexed user, uint256 amount);
    event Withdrawn(address indexed token, address indexed user, uint256 amount);
    event Transferred(address indexed token, address indexed from, address indexed to, uint256 amount);
    event TokenSupportToggled(address indexed token, bool supported);
    event DepositedToAave(address indexed token, uint256 amount, address indexed onBehalfOf); // Added onBehalfOf
    event WithdrawnFromAave(address indexed token, uint256 amount, address indexed to); // Added 'to' recipient

    /**
     * @dev Constructor initializes the contract with an owner, Aave Pool, and Aave Treasury address.
     * @param _aavePool The address of the Aave V3 Pool contract.
     * @param _aaveTreasury The address that will be used as the `onBehalfOf` for supply
     * and potentially receive yields/manage collected interest from Aave.
     * It can also be `address(this)` if the contract manages its own Aave yields.
     */
    constructor(address _aavePool, address _aaveTreasury) Ownable2Step(msg.sender) {
        require(_aavePool != address(0), "Aave Pool address cannot be zero.");
        require(_aaveTreasury != address(0), "Aave Treasury address cannot be zero.");
        aavePool = IPool(_aavePool);
        aaveTreasury = _aaveTreasury;
    }

    // ===== Admin Functions =====

    /**
     * @dev Allows the owner to toggle support for an ERC20 token.
     * Only supported tokens can be used for banking operations.
     * If a token is supported for the first time, it's added to the `supportedTokens` array.
     * @param token Address of the ERC20 token.
     * @param support True to enable support, false to disable.
     */
    function toggleTokenSupport(address token, bool support) external onlyOwner {
        require(token != address(0), "Token address cannot be zero."); // Added check
        if (support && !isSupportedToken[token]) {
            supportedTokens.push(token);
        } else if (!support && isSupportedToken[token]) {
            // Optional: Remove from supportedTokens array if unsupported
            // This is more complex for dynamic arrays and often omitted for simplicity
            // or handled off-chain if the array size is large.
        }
        isSupportedToken[token] = support;
        emit TokenSupportToggled(token, support);
    }

    /**
     * @dev Allows the owner to pause the contract, preventing certain user operations.
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev Allows the owner to unpause the contract, enabling user operations again.
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @dev Returns the list of currently supported ERC20 token addresses.
     */
    function getSupportedTokens() external view returns (address[] memory) {
        return supportedTokens;
    }

    // ===== User Functions =====

    /**
     * @dev Allows users to deposit ERC20 tokens into the contract.
     * Users must first approve this contract to spend their tokens.
     * Uses `whenNotPaused` modifier to prevent deposits when paused.
     * @param token Address of the ERC20 token to deposit.
     * @param amount Amount of tokens to deposit.
     */
    function deposit(address token, uint256 amount) external whenNotPaused nonReentrant { // ADDED: nonReentrant
        require(token != address(0), "Token address cannot be zero."); // Added check
        require(isSupportedToken[token], "Token not supported");
        require(amount > 0, "Amount must be > 0");

        uint256 before = IERC20(token).balanceOf(address(this));
        // Using `call` pattern with `require` for safer ERC20 interactions
        (bool success, ) = IERC20(token).call(abi.encodeWithSelector(IERC20.transferFrom.selector, msg.sender, address(this), amount));
        require(success, "TransferFrom failed");
        uint256 afterTransfer = IERC20(token).balanceOf(address(this));
        uint256 actualReceived = afterTransfer - before;
        require(actualReceived >= amount, "Did not receive expected amount during deposit."); // Ensure full amount or more was received

        balances[token][msg.sender] += actualReceived;
        emit Deposited(token, msg.sender, actualReceived);
    }

    /**
     * @dev Allows users to withdraw ERC20 tokens from the contract.
     * Uses `whenNotPaused` and `nonReentrant` modifiers for safety.
     * @param token Address of the ERC20 token to withdraw.
     * @param amount Amount of tokens to withdraw.
     */
    function withdraw(address token, uint256 amount) external whenNotPaused nonReentrant { // ADDED: nonReentrant
        require(token != address(0), "Token address cannot be zero."); // Added check
        require(isSupportedToken[token], "Token not supported");
        require(amount > 0, "Amount must be > 0");
        require(balances[token][msg.sender] >= amount, "Insufficient balance");

        balances[token][msg.sender] -= amount;
        // Using `call` pattern with `require` for safer ERC20 interactions
        (bool success, ) = IERC20(token).call(abi.encodeWithSelector(IERC20.transfer.selector, msg.sender, amount));
        require(success, "Token transfer failed");
        emit Withdrawn(token, msg.sender, amount);
    }

    /**
     * @dev Allows users to transfer supported tokens internally within the contract to another user.
     * Uses `whenNotPaused` modifier.
     * @param token Address of the ERC20 token to transfer.
     * @param to The recipient's address.
     * @param amount Amount of tokens to transfer.
     */
    function internalTransfer(address token, address to, uint256 amount) external whenNotPaused {
        require(token != address(0), "Token address cannot be zero."); // Added check
        require(to != address(0), "Recipient address cannot be zero."); // Added check
        require(isSupportedToken[token], "Token not supported");
        require(amount > 0, "Amount must be > 0");
        require(balances[token][msg.sender] >= amount, "Insufficient balance");
        require(msg.sender != to, "Cannot transfer to self via internal transfer."); // Prevent self-transfer confusion

        balances[token][msg.sender] -= amount;
        balances[token][to] += amount;
        emit Transferred(token, msg.sender, to, amount);
    }

    /**
     * @dev Retrieves a user's balance for a specific ERC20 token within this contract.
     * @param token Address of the ERC20 token.
     * @param user Address of the user.
     * @return The balance of the token for the given user.
     */
    function getUserBalance(address token, address user) external view returns (uint256) {
        require(token != address(0), "Token address cannot be zero."); // Added check
        require(user != address(0), "User address cannot be zero."); // Added check
        return balances[token][user];
    }

    // ===== Aave Integration =====

    /**
     * @dev Allows the owner to deposit supported tokens held by this contract into Aave for lending.
     * This function should be called with tokens that have *already been deposited* into this contract's
     * internal banking system, or sent directly to this contract.
     * `aaveTreasury` address is used as `onBehalfOf` to track who is supplying.
     * Uses `whenNotPaused` and `nonReentrant` modifiers for safety.
     * @param token Address of the ERC20 token to supply to Aave.
     * @param amount The amount of tokens to supply.
     */
    function depositToAave(address token, uint256 amount) external onlyOwner whenNotPaused nonReentrant { // ADDED: whenNotPaused, nonReentrant
        require(token != address(0), "Token address cannot be zero."); // Added check
        require(amount > 0, "Amount must be > 0");
        require(isSupportedToken[token], "Token not supported");
        require(address(aavePool) != address(0), "Aave Pool contract not set."); // Ensure Aave pool is set

        // Approve Aave pool to pull the amount from this contract
        (bool successApprove, ) = IERC20(token).call(abi.encodeWithSelector(IERC20.approve.selector, address(aavePool), amount));
        require(successApprove, "Aave approval failed");

        // Supply the asset to Aave. The `aaveTreasury` address will be recorded as the on-behalf-of address.
        aavePool.supply(token, amount, aaveTreasury, 0); // Use aaveTreasury as onBehalfOf
        emit DepositedToAave(token, amount, aaveTreasury);
    }

    /**
     * @dev Allows the owner to withdraw previously supplied assets from Aave back to this contract.
     * Uses `whenNotPaused` and `nonReentrant` modifiers for safety.
     * @param token Address of the ERC20 token to withdraw from Aave.
     * @param amount The amount of tokens to withdraw. Use `type(uint256).max` to withdraw all.
     */
    function withdrawFromAave(address token, uint256 amount) external onlyOwner whenNotPaused nonReentrant { // ADDED: whenNotPaused, nonReentrant
        require(token != address(0), "Token address cannot be zero."); // Added check
        require(amount > 0, "Amount must be > 0");
        require(isSupportedToken[token], "Token not supported");
        require(address(aavePool) != address(0), "Aave Pool contract not set."); // Ensure Aave pool is set

        // Withdraw the asset from Aave. Aave will send the tokens directly to `address(this)`.
        aavePool.withdraw(token, amount, address(this));
        emit WithdrawnFromAave(token, amount, address(this)); // Explicitly log destination
    }

    // ===== Emergency Recovery =====

    /**
     * @dev Allows the contract owner to recover any *unsupported* ERC20 tokens accidentally sent to this contract.
     * For supported tokens, the regular `withdraw` function should be used.
     * @param token Address of the ERC20 token to recover.
     * @param amount The amount of tokens to recover.
     */
    function recoverERC20(address token, uint256 amount) external onlyOwner {
        require(token != address(0), "Token address cannot be zero."); // Added check
        require(amount > 0, "Amount must be > 0"); // Added check
        require(!isSupportedToken[token], "Use regular withdraw for supported tokens."); // Clarified message

        (bool success, ) = IERC20(token).call(abi.encodeWithSelector(IERC20.transfer.selector, owner(), amount));
        require(success, "Recovery transfer failed");
    }

    /**
     * @dev Allows the contract owner to recover native token (ETH on EVM) accidentally sent to this contract.
     */
    function recoverNativeToken() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    /**
     * @dev Fallback function to accept native token (ETH on EVM) for accidental transfers.
     */
    receive() external payable {}
}
