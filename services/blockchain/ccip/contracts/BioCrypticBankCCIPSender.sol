// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts-ccip/contracts/interfaces/IRouterClient.sol";
import "@chainlink/contracts-ccip/contracts/libraries/Client.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IBioCrypticBankCrossChainToken} from "./IBioCrypticBankCrossChainToken.sol";

/**
 * @title BioCrypticBankCCIPSender
 * @dev Deployed on source chain (e.g. Avalanche Fuji). Burns CCT and sends CCIP message to destination chain.
 * This contract is responsible for initiating cross-chain token transfers via Chainlink CCIP.
 * It interacts with the CrossChainToken (CCT) to burn tokens on the source chain
 * and then sends a CCIP message to trigger minting on the destination chain.
 *
 * This version encodes the final recipient address into the `data` field of the CCIP message,
 * which will be read by the `BioCrypticBankCCIPReceiver` on the destination chain.
 */
contract BioCrypticBankCCIPSender is Ownable {
    // --- State Variables ---
    IRouterClient private s_router; // Chainlink CCIP Router address
    address private s_linkToken;    // LINK token address used for CCIP fees
    IBioCrypticBankCrossChainToken private s_cctToken; // Address of the CrossChainToken contract, updated type
    address private s_ccipReceiverOnDestination; // Address of the BioCrypticBankCCIPReceiver on the destination chain

    // --- Events ---
    /**
     * @dev Emitted when a cross-chain token transfer request is sent via CCIP.
     * @param messageId The unique ID of the CCIP message.
     * @param destinationChainSelector The Chainlink Chain Selector of the destination chain.
     * @param receiver The address that will receive tokens on the destination chain (the end user).
     * @param amount The amount of CCT tokens transferred.
     * @param feeToken The address of the token used to pay for CCIP fees (LINK or native).
     * @param fees The amount of fees paid for the CCIP transfer.
     */
    event TokensTransferred(
        bytes32 indexed messageId,
        uint64 indexed destinationChainSelector,
        address indexed receiver, // This will now be the end-user receiver
        uint256 amount,
        address feeToken,
        uint256 fees
    );

    // --- Constructor ---
    /**
     * @dev Constructor to initialize the BioCrypticBankCCIPSender contract.
     * @param _router The address of the Chainlink CCIP Router on the current chain.
     * @param _link The address of the LINK token on the current chain.
     * @param _cct The address of the CrossChainToken (CCT) contract on the current chain.
     * @param _ccipReceiverOnDestination The address of the BioCrypticBankCCIPReceiver contract on the destination chain.
     */
    constructor(
        address _router,
        address _link,
        address _cct,
        address _ccipReceiverOnDestination // New parameter for the destination receiver contract address
    ) Ownable(msg.sender) {
        require(_router != address(0), "Invalid router address");
        require(_link != address(0), "Invalid LINK token address");
        require(_cct != address(0), "Invalid CCT token address");
        require(_ccipReceiverOnDestination != address(0), "Invalid CCIP receiver on destination address");

        s_router = IRouterClient(_router);
        s_linkToken = _link;
        s_cctToken = IBioCrypticBankCrossChainToken(_cct);
        s_ccipReceiverOnDestination = _ccipReceiverOnDestination;
    }

    // --- Main Function ---
    /**
     * @dev Burns CCT tokens from the sender's account on the source chain
     * and sends a CCIP message to the destination chain to trigger the minting
     * of an equivalent amount of CCT to the specified receiver.
     * This function is currently restricted to the contract owner for MVP simplicity,
     * but could be opened to general users for a full implementation.
     *
     * The `_receiver` address (the end-user recipient) is encoded into the `data` field.
     * The `message.receiver` field is set to the `BioCrypticBankCCIPReceiver` contract's address
     * on the destination chain, as that contract is the actual receiver of the CCIP message.
     *
     * @param _destinationChainSelector Chainlink selector for the destination chain.
     * @param _receiver Address to receive the tokens on the destination chain (the end user).
     * @param _amount Amount of CCT to transfer.
     * @param _feeToken Token used to pay the CCIP fee (LINK or address(0) for native).
     */
    function transferTokensCrossChain(
        uint64 _destinationChainSelector,
        address _receiver,
        uint256 _amount,
        address _feeToken
    ) external payable onlyOwner {
        require(_receiver != address(0), "Invalid receiver");
        require(_amount > 0, "Amount must be > 0");

        s_cctToken.burn(msg.sender, _amount);

        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({
            token: address(s_cctToken),
            amount: _amount
        });

        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encodePacked(s_ccipReceiverOnDestination), // The actual receiver of the CCIP message is the CCIPReceiver contract
            data: abi.encode(_receiver), // The end-user recipient is encoded in the data field
            tokenAmounts: tokenAmounts,
            extraArgs: Client._argsToBytes(Client.EVMExtraArgsV1({ gasLimit: 0})),
            feeToken: _feeToken
        });

        uint256 fees = s_router.getFee(_destinationChainSelector, message);

        if (_feeToken == s_linkToken) {
            IERC20(s_linkToken).transferFrom(msg.sender, address(this), fees);
            IERC20(s_linkToken).approve(address(s_router), fees);
        } else if (_feeToken == address(0)) {
            require(msg.value >= fees, "Insufficient native token for fees");
        } else {
            revert("Unsupported fee token");
        }

        bytes32 messageId = s_router.ccipSend(_destinationChainSelector, message);

        emit TokensTransferred(
            messageId,
            _destinationChainSelector,
            _receiver, // Emit the end-user receiver
            _amount,
            _feeToken,
            fees
        );
    }

    // --- Admin Utilities ---
    /**
     * @dev Allows the contract owner to fund this contract with LINK tokens.
     * @param _amount The amount of LINK tokens to transfer.
     */
    function fundWithLINK(uint256 _amount) external onlyOwner {
        IERC20(s_linkToken).transferFrom(msg.sender, address(this), _amount);
    }

    /**
     * @dev Allows the contract owner to withdraw LINK tokens from this contract.
     * @param _to The address to send the LINK tokens to.
     */
    function withdrawLINK(address _to) external onlyOwner {
        require(_to != address(0), "Invalid recipient");
        uint256 balance = IERC20(s_linkToken).balanceOf(address(this));
        IERC20(s_linkToken).transfer(_to, balance);
    }

    /**
     * @dev Allows the contract owner to withdraw native tokens (ETH/AVAX) from this contract.
     * @param _to The address to send the native tokens to.
     */
    function withdrawNative(address _to) external onlyOwner {
        require(_to != address(0), "Invalid recipient");
        payable(_to).transfer(address(this).balance);
    }

    /**
     * @dev Sets the address of the BioCrypticBankCCIPReceiver contract on the destination chain.
     * @param _ccipReceiverAddress The new address of the CCIPReceiver on the destination chain.
     */
    function setCCIPReceiverOnDestination(address _ccipReceiverAddress) external onlyOwner {
        require(_ccipReceiverAddress != address(0), "Invalid address");
        s_ccipReceiverOnDestination = _ccipReceiverAddress;
    }

    // --- Views ---
    /**
     * @dev Returns the address of the Chainlink CCIP Router used by this contract.
     */
    function getRouter() external view returns (address) {
        return address(s_router);
    }

    /**
     * @dev Returns the address of the LINK token used by this contract for fees.
     */
    function getLinkToken() external view returns (address) {
        return s_linkToken;
    }

    /**
     * @dev Returns the address of the CrossChainToken (CCT) contract.
     */
    function getCCTToken() external view returns (address) {
        return address(s_cctToken);
    }

    /**
     * @dev Returns the address of the BioCrypticBankCCIPReceiver contract on the destination chain.
     */
    function getCCIPReceiverOnDestination() external view returns (address) {
        return s_ccipReceiverOnDestination;
    }
}
