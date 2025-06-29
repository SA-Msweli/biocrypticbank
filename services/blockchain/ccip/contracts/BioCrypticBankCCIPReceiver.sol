// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip/contracts/applications/CCIPReceiver.sol";
import {Client} from "@chainlink/contracts-ccip/contracts/libraries/Client.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IBioCrypticBankCrossChainToken} from "./IBioCrypticBankCrossChainToken.sol";


/**
 * @title BioCrypticBankCCIPReceiver
 * @dev Deployed on the destination chain (e.g. Ethereum Sepolia).
 * Mints CCT to the recipient upon receiving a valid CCIP message from an authorized sender.
 * This contract inherits from Chainlink's abstract CCIPReceiver to handle incoming CCIP messages
 * and implements custom logic for token minting.
 */
contract BioCrypticBankCCIPReceiver is CCIPReceiver, Ownable {
    // --- State Variables ---
    // i_router is now implicitly managed by the inherited CCIPReceiver contract
    IBioCrypticBankCrossChainToken private s_cctToken;
    mapping(uint64 => mapping(address => bool)) private s_authorizedSenders;

    // --- Events ---
    /**
     * @dev Emitted when CCT tokens are successfully minted on the destination chain
     * after receiving a valid CCIP message.
     * @param messageId The unique ID of the CCIP message.
     * @param sourceChainSelector The Chainlink Chain Selector of the source chain.
     * @param receiver The address that received the tokens.
     * @param amount The amount of CCT tokens received.
     * @param token The address of the token (CCT) that was minted.
     */
    event TokensReceived(
        bytes32 indexed messageId,
        uint64 indexed sourceChainSelector,
        address indexed receiver,
        uint256 amount,
        address token
    );

    /**
     * @dev Emitted when an authorized sender is set or unset for a specific source chain.
     * @param chainSelector The Chainlink Chain Selector of the source chain.
     * @param sender The address of the sender contract on the source chain.
     * @param authorized True if authorized, false if unauthorized.
     */
    event AuthorizedSenderSet(uint64 indexed chainSelector, address indexed sender, bool authorized);

    // --- Constructor ---
    /**
     * @dev Constructor to initialize the BioCrypticBankCCIPReceiver contract.
     * It calls the constructor of the inherited Chainlink CCIPReceiver contract
     * to set the router address.
     * @param _router The address of the Chainlink CCIP Router on the current chain.
     * @param _cctToken The address of the CrossChainToken (CCT) contract on the current chain.
     */
    constructor(address _router, address _cctToken)
        CCIPReceiver(_router) // Call the constructor of the inherited CCIPReceiver
        Ownable(msg.sender)
    {
        require(_cctToken != address(0), "Invalid token");
        s_cctToken = IBioCrypticBankCrossChainToken(_cctToken);
    }

    // --- Main Receive Function ---
    /**
     * @dev Processes a CCIP message containing token transfer instructions.
     * This function overrides the `_ccipReceive` function from the inherited `CCIPReceiver` contract.
     * It performs sender authorization and then mints the corresponding CCT tokens to the recipient.
     *
     * @param message Encoded message received from the source chain, containing sender, receiver, and token amounts.
     */
    function _ccipReceive(Client.Any2EVMMessage memory message) internal override {
        // The check `msg.sender == i_router` is handled by the inherited CCIPReceiver contract.

        uint64 sourceChain = message.sourceChainSelector;
        address sourceSender = abi.decode(message.sender, (address));

        require(
            s_authorizedSenders[sourceChain][sourceSender],
            "Unauthorized source sender"
        );

        require(message.destTokenAmounts.length == 1, "Invalid token transfer");

        address receiver = abi.decode(message.data, (address));

        Client.EVMTokenAmount memory tokenInfo = message.destTokenAmounts[0];
        require(tokenInfo.amount > 0, "Zero amount");

        s_cctToken.mint(receiver, tokenInfo.amount);

        emit TokensReceived(
            message.messageId,
            sourceChain,
            receiver,
            tokenInfo.amount,
            tokenInfo.token
        );
    }

    // --- Admin Functions ---
    /**
     * @dev Allows the contract owner to authorize or unauthorize a sender contract
     * on a specific source chain. This is crucial for security, ensuring only
     * trusted sender contracts can trigger minting on this receiver.
     * @param chainSelector The Chainlink selector of the source chain to configure.
     * @param sender The address of the sender contract on the specified source chain.
     * @param authorized A boolean indicating whether the sender should be authorized (true) or unauthorized (false).
     */
    function setAuthorizedSender(uint64 chainSelector, address sender, bool authorized) external onlyOwner {
        require(sender != address(0), "Zero address");
        s_authorizedSenders[chainSelector][sender] = authorized;
        emit AuthorizedSenderSet(chainSelector, sender, authorized);
    }

    /**
     * @dev Checks if a given sender address on a specific chain is authorized.
     * @param chainSelector The Chainlink selector of the source chain.
     * @param sender The address of the sender contract on the source chain.
     * @return A boolean indicating if the sender is authorized.
     */
    function isAuthorizedSender(uint64 chainSelector, address sender) external view returns (bool) {
        return s_authorizedSenders[chainSelector][sender];
    }

    /**
     * @dev Returns the address of the Chainlink CCIP Router used by this contract.
     * This function delegates to the inherited CCIPReceiver's `getRouter` function.
     * @return The address of the CCIP Router.
     */
    function getRouter() override public view returns (address) {
        return super.getRouter(); // Use super to call the inherited function
    }

    /**
     * @dev Returns the address of the CrossChainToken (CCT) contract managed by this receiver.
     * @return The address of the CCT token.
     */
    function getToken() external view returns (address) {
        return address(s_cctToken);
    }
}