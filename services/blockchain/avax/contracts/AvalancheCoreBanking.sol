// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

// Chainlink Imports for Data Feeds and CCIP
import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import "@chainlink/contracts-ccip/contracts/interfaces/IRouterClient.sol";
import "@chainlink/contracts-ccip/contracts/libraries/Client.sol";
import "@chainlink/contracts-ccip/contracts/applications/CCIPReceiver.sol";

import {IAaveIntegration} from "./IAaveIntegration.sol";
import {IRWAHub} from "./IRWAHub.sol";

// Uniswap V3 SwapRouter interface - Replicated for Avalanche
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
}


/**
 * @title AvalancheCoreBanking
 * @dev This contract provides core banking functionalities for ERC-20 tokens on the Avalanche C-Chain.
 * It allows users to deposit, withdraw, and check balances of supported ERC20 tokens.
 * This contract acts as a central vault for these tokens, similar to a traditional bank account.
 * Includes a reentrancy guard for withdrawal safety.
 * It also facilitates interaction with external DeFi (Aave) protocols and Real-World Asset (RWA) functionalities.
 * Integrates Chainlink Data Feeds for price lookups and Chainlink CCIP for cross-chain token transfers
 * and arbitrary messaging. Now includes on-chain token swapping functionality via Uniswap V3
 * upon receiving CCIP token transfers (if this contract is a destination).
 */
contract AvalancheCoreBanking is Ownable, ReentrancyGuard, Pausable, CCIPReceiver {
    using Client for Client.EVMTokenAmount;
    using Client for Client.EVMTokenAmount[];
    using Client for Client.EVM2AnyMessage;

    mapping(address => mapping(address => uint256)) public balances;
    mapping(address => bool) public isSupportedToken;

    IAaveIntegration public aaveIntegrationContract;
    IRWAHub public rwaHubContract;

    AggregatorV3Interface public priceFeed;
    IRouterClient public immutable i_router;
    ISwapRouter public uniswapV3SwapRouter; // Uniswap V3 Swap Router for Avalanche


    event MessageSent(bytes32 indexed messageId);
    event TokensTransferred(bytes32 indexed messageId, address indexed token, uint256 amount);
    event CCIPMessageReceived(bytes32 indexed messageId, uint64 indexed sourceChainSelector, address indexed sender, bytes data, Client.EVMTokenAmount[] tokenAmounts);
    event CrossChainSwapExecuted(bytes32 indexed messageId, address indexed inputToken, uint256 inputAmount, address indexed outputToken, uint256 outputAmount, address recipient);

    event Deposited(address indexed token, address indexed user, uint256 amount);
    event Withdrawn(address indexed token, address indexed user, uint256 amount);
    event TokenSupportToggled(address indexed token, bool supported);
    event AaveIntegrationContractSet(address indexed newAddress);
    event RWAHubContractSet(address indexed newAddress);
    event SentToAave(address indexed user, address indexed asset, uint256 amount);
    event ReceivedFromAave(address indexed user, address indexed asset, uint256 amount);
    event CollateralSentForRWA(address indexed user, address indexed collateralToken, uint256 amount);


    /**
     * @dev Constructor initializes the contract with an owner, Chainlink Router address, and Uniswap V3 Swap Router.
     * @param _initialOwner The initial owner of the contract.
     * @param _router The address of the Chainlink CCIP Router contract for this chain.
     * @param _uniswapV3SwapRouter The address of the Uniswap V3 Swap Router contract for this chain.
     */
    constructor(address _initialOwner, address _router, address _uniswapV3SwapRouter)
        Ownable(_initialOwner)
        CCIPReceiver(_router)
    {
        require(_router != address(0), "Router address cannot be zero.");
        require(_uniswapV3SwapRouter != address(0), "Uniswap V3 Swap Router address cannot be zero.");
        i_router = IRouterClient(_router);
        uniswapV3SwapRouter = ISwapRouter(_uniswapV3SwapRouter);
    }

    // ===== Admin Functions =====

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
     * @dev Allows the owner to pause the contract, preventing certain operations.
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev Allows the owner to unpause the contract, enabling operations again.
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    // ===== User Functions =====

    /**
     * @dev Allows users to deposit ERC20 tokens into the contract.
     * User must first approve this contract to spend their tokens.
     * @param token Address of the ERC20 token to deposit (e.g., USDC.e, USDT.e).
     * @param amount Amount of tokens to deposit.
     */
    function deposit(address token, uint256 amount) external whenNotPaused {
        require(isSupportedToken[token], "Token not supported for deposit.");
        require(amount > 0, "Deposit amount must be greater than 0.");
        require(token != address(0), "Token address cannot be zero.");
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
    function withdraw(address token, uint256 amount) external nonReentrant whenNotPaused {
        require(isSupportedToken[token], "Token not supported for withdrawal.");
        require(amount > 0, "Withdrawal amount must be greater than 0.");
        require(balances[token][msg.sender] >= amount, "Insufficient balance.");
        require(token != address(0), "Token address cannot be zero.");

        balances[token][msg.sender] -= amount;
        IERC20(token).transfer(msg.sender, amount);
        emit Withdrawn(token, msg.sender, amount);
    }

    /**
     * @dev Allows a user to move supported tokens from their balance in this bank to Aave for lending.
     * This contract transfers the tokens to the `aaveIntegrationContract` which then supplies them to Aave.
     * @param asset The address of the ERC20 token to lend (must be a supported token in this bank).
     * @param amount The amount of tokens to send to Aave.
     */
    function depositIntoAave(address asset, uint256 amount) external nonReentrant whenNotPaused {
        require(address(aaveIntegrationContract) != address(0), "Aave Integration contract not set.");
        require(isSupportedToken[asset], "Asset not supported by this bank for lending.");
        require(amount > 0, "Amount must be greater than 0.");
        require(balances[asset][msg.sender] >= amount, "Insufficient balance in bank account.");

        balances[asset][msg.sender] -= amount;

        IERC20(asset).transfer(address(aaveIntegrationContract), amount);

        IAaveIntegration(address(aaveIntegrationContract)).supplyAsset(asset, amount, address(this));

        emit SentToAave(msg.sender, asset, amount);
    }

    /**
     * @dev Allows a user to withdraw assets from Aave and receive them back into their bank balance.
     * This calls the `aaveIntegrationContract` to initiate the withdrawal from Aave.
     * The AaveIntegration contract *must* then transfer the withdrawn assets back to this contract (address(this)).
     * This function *then* credits the user's internal balance.
     * @param asset The address of the ERC20 token to withdraw from Aave.
     * @param amount The amount of tokens to withdraw. Use type(uint256).max to withdraw all.
     */
    function withdrawFromAave(address asset, uint256 amount) external nonReentrant whenNotPaused {
        require(address(aaveIntegrationContract) != address(0), "Aave Integration contract not set.");
        require(isSupportedToken[asset], "Asset not supported by this bank for withdrawal from Aave.");
        require(amount > 0, "Amount must be greater than 0.");

        uint256 initialContractBalance = IERC20(asset).balanceOf(address(this));

        IAaveIntegration(address(aaveIntegrationContract)).withdrawAsset(asset, amount, address(this));

        uint256 receivedAmount = IERC20(asset).balanceOf(address(this)) - initialContractBalance;
        require(receivedAmount >= amount, "Did not receive expected amount from Aave withdrawal.");

        balances[asset][msg.sender] += receivedAmount;

        emit ReceivedFromAave(msg.sender, asset, receivedAmount);
    }

    /**
     * @dev Allows a user to send supported collateral tokens to the RWAHub contract.
     * These tokens are typically used to back RWA-related operations (e.g., fractionalization, loans).
     * The RWAHub must be set and supported token.
     * @param collateralToken The address of the ERC20 token to send as collateral.
     * @param amount The amount of collateral to send.
     */
    function sendCollateralForRWA(address collateralToken, uint256 amount) external nonReentrant whenNotPaused {
        require(address(rwaHubContract) != address(0), "RWA Hub contract not set.");
        require(isSupportedToken[collateralToken], "Collateral token not supported by this bank.");
        require(amount > 0, "Amount must be greater than 0.");
        require(balances[collateralToken][msg.sender] >= amount, "Insufficient balance in bank account.");

        balances[collateralToken][msg.sender] -= amount;

        IERC20(collateralToken).transfer(address(rwaHubContract), amount);

        // TODO: Consider if RWAHub needs to be called to acknowledge receipt or process this collateral.
        // For example, rwaHubContract.depositCollateral(msg.sender, collateralToken, amount);

        emit CollateralSentForRWA(msg.sender, collateralToken, amount);
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
        // The destination contract (e.g., BioCrypticEvmCoreBanking.sol) will decode these.
        bytes memory swapInstructions = abi.encode(targetOutputToken, finalRecipient);

        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            // Receiver on the destination chain is the target banking contract itself,
            // as it will perform the swap and then forward to the final recipient.
            receiver: finalRecipient, // The final recipient, the receiving contract will pass it on.
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
                fee: 3000, // Common 0.3% fee tier for Uniswap V3
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
     * @param tokenAddress The address of the ERC20 token to recover.
     * @param amount The amount of tokens to recover.
     */
    function recoverERC20(address tokenAddress, uint256 amount) external onlyOwner {
        require(tokenAddress != address(0), "Token address cannot be zero.");
        require(amount > 0, "Amount must be greater than 0.");
        require(!isSupportedToken[tokenAddress] || msg.sender == owner(), "Cannot recover supported tokens without owner permission.");
        IERC20(tokenAddress).transfer(owner(), amount);
    }

    /**
     * @dev Allows the contract owner to recover native token (AVAX on EVM) accidentally sent to this contract.
     */
    function recoverNativeToken() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    /**
     * @dev Fallback function to accept native token (AVAX on EVM) for accidental transfers.
     */
    receive() external payable {}
}
