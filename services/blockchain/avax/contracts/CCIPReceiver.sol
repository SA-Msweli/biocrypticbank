// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19; // Using 0.8.19 as specified in hardhat.config.ts

import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts-ccip/contracts/applications/CCIPReceiver.sol";    // Corrected import path;
import "@chainlink/contracts-ccip/contracts/libraries/Client.sol"; // Corrected import path
import "./CrossChainToken.sol"; // Import our custom CrossChainToken

/**
 * @title CCIPReceiver
 * @dev This contract is deployed on the destination chain (Ethereum Sepolia).
 * It receives cross-chain messages and tokens via Chainlink CCIP.
 * Upon receiving a valid message with tokens, it mints the corresponding
 * CrossChainToken (CCT) amount to the specified recipient.
 * This contract must be granted the MINTER_ROLE on the CCT contract on this chain.
 */
contract CCIPReceiver is CCIPReceiver, Ownable {
    // --- State Variables ---
    // The address of the CrossChainToken (CCT) deployed on this destination chain.
    CrossChainToken private s_cctToken;

    // --- Events ---
    event TokensReceived(
        bytes32 indexed messageId,
        uint64 indexed sourceChainSelector,
        address indexed sender,
        address indexed receiver,
        uint256 amount,
        address token
    );

    // --- Constructor ---
    /**
     * @dev Constructor to initialize the CCIPReceiver contract.
     * @param _router The address of the Chainlink CCIP Router on this chain.
     * @param _cct The address of the CrossChainToken (CCT) on this chain.
     */
    constructor(address _router, address _cct) CCIPReceiver(_router) Ownable() {
        require(_cct != address(0), "CCIPReceiver: Invalid CCT token address");
        s_cctToken = CrossChainToken(_cct);
    }

    // --- CCIP Message Handling ---
    /**
     * @dev Overrides the `_ccipReceive` function from `CCIPReceiver.sol`.
     * This function is automatically called by the Chainlink CCIP Router
     * when a cross-chain message is successfully delivered to this contract.
     * It handles the logic for minting CCT to the recipient.
     * @param _message The received CCIP message containing sender, tokens, and data.
     */
    function _ccipReceive(Client.EVM2AnyMessage memory _message) internal override {
        // Ensure the message contains token amounts (as this contract is for token transfers)
        require(_message.tokenAmounts.length > 0, "CCIPReceiver: No tokens in message");
        // We expect only one token type to be transferred for this MVP's CCT
        require(_message.tokenAmounts.length == 1, "CCIPReceiver: Multiple token types not supported in MVP");

        // Get the recipient address from the message data
        // For a token-only transfer, the receiver is typically an EOA encoded in the 'receiver' field.
        // For programmable token transfers, 'data' field would be used to decode more complex instructions.
        // In our MVP, we expect the `receiver` field to contain the EOA of the recipient.
        address recipient = abi.decode(_message.receiver, (address));

        // Get the token and amount from the message
        address tokenAddress = _message.tokenAmounts[0].token;
        uint256 amount = _message.tokenAmounts[0].amount;

        // Verify that the token being received is our expected CCT
        require(tokenAddress == address(s_cctToken), "CCIPReceiver: Received token is not the expected CCT");

        // Mint the CCT to the recipient.
        // This contract must have the MINTER_ROLE granted on the CrossChainToken contract.
        s_cctToken.mint(recipient, amount);

        // Emit an event for tracking the received tokens
        emit TokensReceived(
            _message.messageId,
            _message.sourceChainSelector,
            recipient, // The actual sender on the source chain (deduced from message context if needed)
            recipient, // The recipient on this chain
            amount,
            tokenAddress
        );
    }

    // --- View Functions ---
    /**
     * @dev Returns the address of the CrossChainToken (CCT) managed by this receiver.
     */
    function getCCTToken() public view returns (address) {
        return address(s_cctToken);
    }
}
