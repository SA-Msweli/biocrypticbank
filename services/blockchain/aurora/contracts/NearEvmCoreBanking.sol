// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

// Chainlink Imports for Data Feeds and CCIP
import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import "@chainlink/contracts-ccip/contracts/interfaces/IRouterClient.sol";
import "@chainlink/contracts-ccip/contracts/libraries/Client.sol";
import "@chainlink/contracts-ccip/contracts/applications/CCIPReceiver.sol";

// Aave V3 Pool interface
import {IPool} from "@aave/core-v3/contracts/interfaces/IPool.sol";

// Uniswap V3 SwapRouter interface
interface ISwapRouter {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee; // CORRECTED: Changed from uint252 to uint24 as per Uniswap V3 standard
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);
    // Add other swap functions if needed (e.g., exactOutputSingle, exactInput)
}


/**
 * @title BioCrypticEvmCoreBanking
 * @dev Secure vault for managing ERC-20 tokens on Aurora with support for whitelisted tokens,
 * safe deposit logic, Aave yield integration, internal transfers, emergency pause, and recovery tools.
 * Implements Chainlink Data Feeds for price lookups and Chainlink CCIP for cross-chain token transfers
 * and arbitrary messaging. Now includes on-chain token swapping functionality via Uniswap V3
 * upon receiving CCIP token transfers.
 * Uses a manual two-step ownership transfer and standard Ownable, Pausable, and ReentrancyGuard.
 */
contract BioCrypticEvmCoreBanking is Ownable, Pausable, ReentrancyGuard, CCIPReceiver { // CORRECTED: Fixed typo 'PaentrancyGuard' to 'Pausable, ReentrancyGuard'
    using Client for Client.EVMTokenAmount;
    using Client for Client.EVMTokenAmount[];
    using Client for Client.EVM2AnyMessage;

    mapping(address => mapping(address => uint256)) public balances;
    mapping(address => bool) public isSupportedToken;
    address[] public supportedTokens;

    IPool public aavePool;
    address public aaveTreasury;

    address private _pendingOwner;

    AggregatorV3Interface public priceFeed;
    IRouterClient public immutable i_router;
    ISwapRouter public uniswapV3SwapRouter; // Uniswap V3 Swap Router


    event MessageSent(bytes32 indexed messageId);
    event TokensTransferred(bytes32 indexed messageId, address indexed token, uint256 amount);
    event CCIPMessageReceived(bytes32 indexed messageId, uint64 indexed sourceChainSelector, address indexed sender, bytes data, Client.EVMTokenAmount[] tokenAmounts);
    event CrossChainSwapExecuted(bytes32 indexed messageId, address indexed inputToken, uint256 inputAmount, address indexed outputToken, uint256 outputAmount, address recipient);

    event Deposited(address indexed token, address indexed user, uint256 amount);
    event Withdrawn(address indexed token, address indexed user, uint256 amount); // Reverted to uint256 as Aave compatibility only for supply
    event Transferred(address indexed token, address indexed from, address indexed to, uint256 amount);
    event TokenSupportToggled(address indexed token, bool supported);
    event DepositedToAave(address indexed token, uint256 amount, address indexed onBehalfOf);
    event WithdrawnFromAave(address indexed token, uint256 amount, address indexed to);
    event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner);


    /**
     * @dev Constructor initializes the contract with an owner, Aave Pool, Aave Treasury, and Chainlink Router.
     * @param _initialOwner The initial owner of the contract.
     * @param _aavePool The address of the Aave V3 Pool contract.
     * @param _aaveTreasury The address that will be used as the `onBehalfOf` for supply
     * and potentially receive yields/manage collected interest from Aave.
     * @param _router The address of the Chainlink CCIP Router contract for this chain.
     * @param _uniswapV3SwapRouter The address of the Uniswap V3 Swap Router contract.
     */
    constructor(address _initialOwner, address _aavePool, address _aaveTreasury, address _router, address _uniswapV3SwapRouter)
        Ownable(_initialOwner)
        CCIPReceiver(_router)
    {
        require(_aavePool != address(0), "Aave Pool address cannot be zero.");
        require(_aaveTreasury != address(0), "Aave Treasury address cannot be zero.");
        require(_router != address(0), "Router address cannot be zero.");
        require(_uniswapV3SwapRouter != address(0), "Uniswap V3 Swap Router address cannot be zero.");

        aavePool = IPool(_aavePool);
        aaveTreasury = _aaveTreasury;
        i_router = IRouterClient(_router);
        uniswapV3SwapRouter = ISwapRouter(_uniswapV3SwapRouter);
    }

    // ===== Admin Functions =====

    /**
     * @dev Starts the transfer of ownership of the contract to a new address.
     * Can only be called by the current owner.
     * The new owner must call `acceptOwnership` to complete the transfer.
     * @param newOwner The address of the new owner.
     */
    function transferOwnership(address newOwner) public override onlyOwner {
        require(newOwner != address(0), "New owner is the zero address");
        require(newOwner != owner(), "New owner is already the current owner");
        _pendingOwner = newOwner;
        emit OwnershipTransferStarted(owner(), newOwner);
    }

    /**
     * @dev Allows the pending owner to accept the transfer of ownership.
     * This completes the two-step ownership transfer process.
     */
    function acceptOwnership() public {
        require(msg.sender == _pendingOwner, "You are not the pending owner");
        _transferOwnership(msg.sender);
        _pendingOwner = address(0);
    }

    /**
     * @dev Allows the owner to set or update the Chainlink Price Feed address.
     * @param _priceFeedAddress The address of the AggregatorV3Interface (Price Feed).
     */
    function setPriceFeed(address _priceFeedAddress) external onlyOwner {
        require(_priceFeedAddress != address(0), "Price Feed address cannot be zero.");
        priceFeed = AggregatorV3Interface(_priceFeedAddress);
    }

    /**
     * @dev Allows the owner to set or update the Uniswap V3 Swap Router address.
     * @param _newRouterAddress The address of the Uniswap V3 Swap Router contract.
     */
    function setUniswapV3SwapRouter(address _newRouterAddress) external onlyOwner {
        require(_newRouterAddress != address(0), "New Uniswap V3 Swap Router address cannot be zero.");
        uniswapV3SwapRouter = ISwapRouter(_newRouterAddress);
    }

    /**
     * @dev Allows the owner to toggle support for an ERC20 token.
     * Only supported tokens can be used for banking operations.
     * If a token is supported for the first time, it's added to the `supportedTokens` array.
     * @param token Address of the ERC20 token.
     * @param support True to enable support, false to disable.
     */
    function toggleTokenSupport(address token, bool support) external onlyOwner {
        require(token != address(0), "Token address cannot be zero.");
        if (support && !isSupportedToken[token]) {
            supportedTokens.push(token);
        } else if (!support && isSupportedToken[token]) {
            // Optional: Implement removal from supportedTokens array if needed
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
    function deposit(address token, uint256 amount) external whenNotPaused nonReentrant {
        require(token != address(0), "Token address cannot be zero.");
        require(isSupportedToken[token], "Token not supported");
        require(amount > 0, "Amount must be > 0");

        uint256 before = IERC20(token).balanceOf(address(this));
        (bool success, ) = address(token).call(abi.encodeWithSelector(IERC20.transferFrom.selector, msg.sender, address(this), amount));
        require(success, "TransferFrom failed");
        uint256 afterTransfer = IERC20(token).balanceOf(address(this));
        uint256 actualReceived = afterTransfer - before;
        require(actualReceived >= amount, "Did not receive expected amount during deposit.");

        balances[token][msg.sender] += actualReceived;
        emit Deposited(token, msg.sender, actualReceived);
    }

    /**
     * @dev Allows users to withdraw ERC20 tokens from the contract.
     * Uses `whenNotPaused` and `nonReentrant` modifiers for safety.
     * @param token Address of the ERC20 token to withdraw.
     * @param amount Amount of tokens to withdraw.
     */
    function withdraw(address token, uint256 amount) external whenNotPaused nonReentrant {
        require(token != address(0), "Token address cannot be zero.");
        require(isSupportedToken[token], "Token not supported");
        require(amount > 0, "Amount must be > 0");
        require(balances[token][msg.sender] >= amount, "Insufficient balance");

        balances[token][msg.sender] -= amount;
        (bool success, ) = address(token).call(abi.encodeWithSelector(IERC20.transfer.selector, msg.sender, amount));
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
        require(token != address(0), "Token address cannot be zero.");
        require(to != address(0), "Recipient address cannot be zero.");
        require(isSupportedToken[token], "Token not supported");
        require(amount > 0, "Amount must be > 0");
        require(balances[token][msg.sender] >= amount, "Insufficient balance");
        require(msg.sender != to, "Cannot transfer to self via internal transfer.");

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
        require(token != address(0), "Token address cannot be zero.");
        require(user != address(0), "User address cannot be zero.");
        return balances[token][user];
    }

    // ===== Chainlink Data Feed Integration =====

    /**
     * @dev Returns the latest price from the configured Chainlink Price Feed.
     * Assumes the priceFeed is set.
     * @return latestPrice The latest price.
     * @return timestamp The timestamp of the latest price update.
     */
    function getLatestPrice() external view returns (int256 latestPrice, uint256 timestamp) {
        require(address(priceFeed) != address(0), "Price Feed not set.");
        (, int256 price, , uint256 updatedAt, ) = priceFeed.latestRoundData();
        return (price, updatedAt);
    }

    // ===== Aave Integration =====

    /**
     * @dev Allows the owner to deposit supported tokens held by this contract into Aave for lending.
     * This function should be called with tokens that have *already been deposited* into this contract's
     * internal banking system, or sent directly to this contract.
     * `aaveTreasury` address is used as the `onBehalfOf` for supply
     * and potentially receive yields/manage collected interest from Aave.
     * Uses `whenNotPaused` and `nonReentrant` modifiers for safety.
     * @param token Address of the ERC20 token to supply to Aave.
     * @param amount The amount of tokens to supply.
     */
    function depositToAave(address token, uint256 amount) external onlyOwner whenNotPaused nonReentrant {
        require(token != address(0), "Token address cannot be zero.");
        require(amount > 0, "Amount must be > 0");
        require(isSupportedToken[token], "Token not supported");
        require(address(aavePool) != address(0), "Aave Pool contract not set.");

        require(IERC20(token).balanceOf(address(this)) >= amount, "Insufficient contract balance to deposit to Aave.");

        (bool successApprove, ) = address(token).call(abi.encodeWithSelector(IERC20.approve.selector, address(aavePool), amount));
        require(successApprove, "Aave approval failed");

        aavePool.supply(token, amount, aaveTreasury, 0);
        emit DepositedToAave(token, amount, aaveTreasury);
    }

    /**
     * @dev Allows the owner to withdraw previously supplied assets from Aave back to this contract.
     * Uses `whenNotPaused` and `nonReentrant` modifiers for safety.
     * @param token Address of the ERC20 token to withdraw from Aave.
     * @param amount The amount of tokens to withdraw. Use `type(uint256).max` to withdraw all.
     */
    function withdrawFromAave(address token, uint256 amount) external onlyOwner whenNotPaused nonReentrant {
        require(token != address(0), "Token address cannot be zero.");
        require(amount > 0, "Amount must be > 0");
        require(isSupportedToken[token], "Token not supported");
        require(address(aavePool) != address(0), "Aave Pool contract not set.");

        aavePool.withdraw(token, amount, address(this));
        emit WithdrawnFromAave(token, amount, address(this));
    }

    // ===== Chainlink CCIP Integration with On-Chain Swap =====

    /**
     * @dev Sends ERC20 tokens from this contract to a recipient on a different blockchain via CCIP,
     * with an instruction to perform a swap on the destination chain.
     * The `msg.sender` must first have deposited the tokens into this contract's balance.
     * This function will:
     * 1. Deduct tokens from the caller's internal `balances` mapping.
     * 2. Approve the Chainlink CCIP Router to pull the specified `inputToken` from this contract's balance.
     * 3. Encode `targetOutputToken` and `finalRecipient` into the `data` field of the CCIP message.
     * 4. Send the CCIP message, which includes the `inputToken` and the encoded swap instructions.
     * Upon arrival, `_ccipReceive` on the destination will handle the swap and final transfer.
     * Requires sufficient LINK or native gas token (sent via `msg.value`) to cover CCIP fees.
     * Protected by `whenNotPaused` and `nonReentrant` modifiers.
     * @param destinationChainSelector The Chainlink Chain Selector for the target blockchain.
     * @param inputToken The address of the ERC20 token to send from the source chain.
     * @param amount The amount of `inputToken` to send.
     * @param targetOutputToken The address of the ERC20 token the user wishes to receive after the swap on the destination.
     * @param finalRecipient The address of the ultimate recipient on the destination blockchain, who receives the swapped tokens.
     * @param feeAmount The amount of LINK (or native gas token) to pay for CCIP fees.
     */
    function transferAndSwapCrossChain(
        uint64 destinationChainSelector,
        address inputToken,
        uint256 amount,
        address targetOutputToken,
        address finalRecipient,
        uint256 feeAmount // Amount of LINK to send for fees (msg.value if native)
    ) external payable whenNotPaused nonReentrant {
        require(inputToken != address(0), "Input token address cannot be zero.");
        require(isSupportedToken[inputToken], "Input token not supported for cross-chain transfer.");
        require(amount > 0, "Amount must be greater than 0.");
        require(balances[inputToken][msg.sender] >= amount, "Insufficient balance for cross-chain transfer.");
        require(targetOutputToken != address(0), "Target output token address cannot be zero.");
        require(finalRecipient != address(0), "Final recipient address cannot be zero.");

        balances[inputToken][msg.sender] -= amount;

        (bool successApprove, ) = address(inputToken).call(abi.encodeWithSelector(IERC20.approve.selector, address(i_router), amount));
        require(successApprove, "Failed to approve router for token transfer.");

        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({
            token: inputToken,
            amount: amount
        });

        // Encode instructions for the swap on the destination chain into message.data
        // (targetOutputToken, finalRecipient)
        bytes memory swapInstructions = abi.encode(targetOutputToken, finalRecipient);

        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: address(this), // This contract is the receiver on the destination, it will handle the swap.
            data: swapInstructions, // Custom data for swap instructions
            tokenAmounts: tokenAmounts,
            extraArgs: Client.EVM2AnyMessage.ExtraArgsV1({
                gasLimit: 500_000, // Increased gas limit to accommodate swap operation
                strict: false
            }).encode(),
            feeToken: address(0)
        });

        uint256 fees = i_router.getFee(destinationChainSelector, message);
        require(msg.value >= fees + feeAmount, "Insufficient LINK or native token for CCIP fees.");

        bytes32 messageId = i_router.ccipSend{value: msg.value}(
            destinationChainSelector,
            message
        );

        emit MessageSent(messageId);
        emit TokensTransferred(messageId, inputToken, amount);
    }

    /**
     * @dev Handles incoming CCIP messages (arbitrary data or token transfers).
     * This function is called by the Chainlink CCIP Router on receipt of a cross-chain message.
     * It now includes logic to perform an on-chain swap if `message.data` contains swap instructions.
     * Implements `CCIPReceiver`'s `_ccipReceive` callback.
     * @param message The received CCIP message.
     */
    function _ccipReceive(Client.Message calldata message) internal override {
        // Ensure this contract is set as the Uniswap Router for the swap.
        require(address(uniswapV3SwapRouter) != address(0), "Uniswap V3 Swap Router not set.");

        // Check if there are tokens AND swap instructions in the message data
        if (message.tokenAmounts.length > 0 && message.data.length > 0) {
            // Assume the first token is the one to be swapped
            address inputTokenAddress = message.tokenAmounts[0].token;
            uint256 inputAmount = message.tokenAmounts[0].amount;

            // Decode swap instructions from message.data
            (address targetOutputToken, address finalRecipient) = abi.decode(message.data, (address, address));

            // Ensure the contract has enough balance of the input token (CCIP router already transferred it)
            require(IERC20(inputTokenAddress).balanceOf(address(this)) >= inputAmount, "Insufficient received tokens for swap.");

            // Approve the Uniswap V3 Swap Router to spend the input tokens from this contract
            (bool successApprove, ) = address(inputTokenAddress).call(abi.encodeWithSelector(IERC20.approve.selector, address(uniswapV3SwapRouter), inputAmount));
            require(successApprove, "Failed to approve Uniswap Router for swap.");

            // Perform the swap using Uniswap V3's exactInputSingle
            // For simplicity, fee is set to a common Uniswap V3 fee (e.g., 0.3% = 3000),
            // and amountOutMinimum is set to 0. In a production system, these should be configurable
            // or derived dynamically (e.g., from Chainlink Data Feeds + slippage tolerance).
            ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
                tokenIn: inputTokenAddress,
                tokenOut: targetOutputToken,
                fee: 3000, // Common 0.3% fee tier
                recipient: address(this), // Send the output tokens back to this contract first
                deadline: block.timestamp + 600, // 10 minutes from now
                amountIn: inputAmount,
                amountOutMinimum: 0, // IMPORTANT: For production, this should be set by sender/backend for slippage control
                sqrtPriceLimitX96: 0 // No price limit
            });

            // Execute the swap
            uint256 amountOut = uniswapV3SwapRouter.exactInputSingle(params);

            // Transfer the swapped tokens to the final recipient
            (bool successTransfer, ) = address(targetOutputToken).call(abi.encodeWithSelector(IERC20.transfer.selector, finalRecipient, amountOut));
            require(successTransfer, "Failed to transfer swapped tokens to final recipient.");

            emit CrossChainSwapExecuted(
                message.messageId,
                inputTokenAddress,
                inputAmount,
                targetOutputToken,
                amountOut,
                finalRecipient
            );
        } else {
            // Handle cases where no swap is intended, but tokens or data are received
            for (uint256 i = 0; i < message.tokenAmounts.length; i++) {
                Client.EVMTokenAmount memory tokenAmount = message.tokenAmounts[i];
                // TODO: For tokens received without swap instructions, credit to an internal banking account
                // or handle as a direct cross-chain transfer into this contract's main balance.
                // Example: balances[tokenAmount.token][someDefaultRecipient] += tokenAmount.amount;
            }

            if (message.data.length > 0) {
                // TODO: Process `message.data` for arbitrary messaging without token swaps (e.g., RWA updates).
            }
        }

        // Always emit the general CCIP message received event
        emit CCIPMessageReceived(
            message.messageId,
            message.sourceChainSelector,
            message.sender,
            message.data,
            message.tokenAmounts
        );
    }


    // ===== Emergency Recovery =====

    /**
     * @dev Allows the contract owner to recover any *unsupported* ERC20 tokens accidentally sent to this contract.
     * For supported tokens, the regular `withdraw` function should be used.
     * @param token Address of the ERC20 token to recover.
     * @param amount The amount of tokens to recover.
     */
    function recoverERC20(address token, uint256 amount) external onlyOwner {
        require(token != address(0), "Token address cannot be zero.");
        require(amount > 0, "Amount must be > 0");
        require(!isSupportedToken[token], "Use regular withdraw for supported tokens.");

        (bool success, ) = address(token).call(abi.encodeWithSelector(IERC20.transfer.selector, owner(), amount));
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
