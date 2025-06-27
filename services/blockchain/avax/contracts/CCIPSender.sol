// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19; // Using 0.8.19 as specified in hardhat.config.ts

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts-ccip/contracts/interfaces/IRouterClient.sol";
import "@chainlink/contracts-ccip/contracts/libraries/Client.sol";

/**
 * @title CCIPSender
 * @dev This contract is deployed on the source chain (Avalanche Fuji).
 * It facilitates sending CrossChainToken (CCT) and a message to a destination chain
 * via Chainlink CCIP. It also burns the CCT from the sender on the source chain.
 */
contract CCIPSender is Ownable {
    // --- State Variables ---
    IRouterClient private s_router; // Chainlink CCIP Router contract interface
    address private s_linkToken;    // LINK token address used for CCIP fees
    address private s_cctToken;     // CrossChainToken (CCT) address

    // --- Events ---
    event TokensTransferred(
        bytes32 indexed messageId,
        uint64 indexed destinationChainSelector,
        address indexed receiver,
        uint256 amount,
        address feeToken,
        uint256 fees
    );

    event MessageSent(
        bytes32 indexed messageId,
        uint64 indexed destinationChainSelector,
        address indexed receiver,
        bytes data,
        address feeToken,
        uint256 fees
    );

    // --- Constructor ---
    /**
     * @dev Constructor to initialize the CCIPSender contract.
     * @param _router The address of the Chainlink CCIP Router on this chain.
     * @param _link The address of the LINK token on this chain, used for CCIP fees.
     * @param _cct The address of the CrossChainToken (CCT) on this chain.
     */
    constructor(address _router, address _link, address _cct) Ownable() {
        require(_router != address(0), "CCIPSender: Invalid router address");
        require(_link != address(0), "CCIPSender: Invalid LINK token address");
        require(_cct != address(0), "CCIPSender: Invalid CCT token address");
        s_router = IRouterClient(_router);
        s_linkToken = _link;
        s_cctToken = _cct;
    }

    // --- Public Functions ---

    /**
     * @dev Sends CrossChainToken (CCT) to a recipient on a destination chain using CCIP.
     * The CCT tokens are burned on this (source) chain, and a message is sent to the
     * destination chain to mint an equivalent amount.
     * Requires the sender to have approved this contract to spend the CCT and LINK tokens.
     *
     * @param _destinationChainSelector The Chainlink CCIP selector for the destination blockchain.
     * @param _receiver The address of the recipient on the destination chain (can be EOA or contract).
     * @param _amount The amount of CCT tokens to transfer.
     * @param _feeToken The address of the token used to pay CCIP fees (LINK or native token).
     */
    function transferTokensCrossChain(
        uint64 _destinationChainSelector,
        address _receiver,
        uint256 _amount,
        address _feeToken // Could be s_linkToken or address(0) for native
    ) external onlyOwner { // Changed to onlyOwner for MVP, can be changed to public for dApp users later

        // Ensure the CCT contract on this chain has the BURNER_ROLE for this CCIPSender.
        // This is a crucial configuration step that must be done by the CCT owner separately.
        // For the MVP, we assume this is pre-configured.
        IERC20(s_cctToken).burn(msg.sender, _amount); // Burn CCT from the sender

        // Build the CCIP message
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encodePacked(_receiver), // Encode recipient address
            data: "",                              // No arbitrary data for token-only transfer in MVP
            tokenAmounts: new Client.EVMTokenAmount[](1), // Array for one token transfer
            extraArgs: Client._argsToBytes(Client.EVMExtraArgsV1({ gasLimit: 0, strict: false })),
            feeToken: _feeToken                     // Token to pay for fees (LINK or native)
        });

        // Set the token amount for the message
        message.tokenAmounts[0] = Client.EVMTokenAmount({
            token: s_cctToken,
            amount: _amount
        });

        // Get the fee required for the transaction
        uint256 fees = s_router.getFee(_destinationChainSelector, message);

        // Approve the router to spend the fee token from this contract
        // If _feeToken is LINK, approve LINK. If native, it's paid directly.
        if (_feeToken == s_linkToken) {
            IERC20(s_linkToken).transferFrom(msg.sender, address(this), fees); // Pull LINK from sender
            IERC20(s_linkToken).approve(address(s_router), fees); // Approve router to spend LINK from this contract
        } else if (_feeToken == address(0)) { // Native token payment
            require(msg.value >= fees, "CCIPSender: Not enough native token to pay for fees");
        } else {
            revert("CCIPSender: Unsupported fee token");
        }

        // Send the CCIP message
        bytes32 messageId = s_router.ccipSend(_destinationChainSelector, message);

        // Emit an event for tracking
        emit TokensTransferred(
            messageId,
            _destinationChainSelector,
            _receiver,
            _amount,
            _feeToken,
            fees
        );
    }

    // --- Helper Functions ---

    /**
     * @dev Allows the owner to fund this contract with LINK tokens for future fees
     * if the fee payment strategy is to pre-fund the contract.
     * @param _amount The amount of LINK tokens to transfer to this contract.
     */
    function fundWithLINK(uint256 _amount) public onlyOwner {
        IERC20(s_linkToken).transferFrom(msg.sender, address(this), _amount);
    }

    /**
     * @dev Allows the owner to retrieve LINK tokens from this contract.
     * @param _to The address to send the LINK tokens to.
     */
    function withdrawLINK(address _to) public onlyOwner {
        IERC20(s_linkToken).transfer(_to, IERC20(s_linkToken).balanceOf(address(this)));
    }

    /**
     * @dev Allows the owner to retrieve any native tokens mistakenly sent to this contract.
     * @param _to The address to send the native tokens to.
     */
    function withdrawNative(address _to) public onlyOwner {
        payable(_to).transfer(address(this).balance);
    }

    // --- View Functions ---
    function getRouter() public view returns (address) {
        return address(s_router);
    }

    function getLinkToken() public view returns (address) {
        return s_linkToken;
    }

    function getCCTToken() public view returns (address) {
        return s_cctToken;
    }
}
