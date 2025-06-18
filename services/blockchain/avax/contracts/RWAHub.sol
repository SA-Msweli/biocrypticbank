// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol"; // For potential fee payments or associated value

/**
 * @title RWAHub
 * @dev This contract serves as a central hub for managing tokenized Real-World Assets (RWAs) on Avalanche.
 * It allows for the issuance (minting) of new RWA tokens (ERC-721 in this example, representing unique assets),
 * and provides functions for managing their lifecycle.
 * In a real-world scenario, this would integrate with off-chain legal entities and physical asset data.
 */
contract RWAHub is Ownable, ERC721 {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;

    // Mapping from RWA Token ID to detailed asset information (e.g., hash of off-chain documentation)
    mapping(uint256 => string) public assetMetadataURIs;
    // Mapping to track if an RWA is active/valid
    mapping(uint256 => bool) public isRWAActive;

    event RWAIssued(uint256 indexed tokenId, address indexed owner, string uri, string metadataURI);
    event RWAStatusChanged(uint256 indexed tokenId, bool newStatus);
    event RWATransfer(uint256 indexed tokenId, address indexed from, address indexed to);

    /**
     * @dev Constructor initializes the ERC721 token with a name and symbol.
     * @param name The name of the RWA token collection (e.g., "Digital Real Estate").
     * @param symbol The symbol of the RWA token collection (e.g., "DRE").
     */
    constructor(string memory name, string memory symbol) Ownable(msg.sender) ERC721(name, symbol) {
        // Initial setup
    }

    /**
     * @dev Mints a new RWA token and assigns it to an owner. Only the contract owner can mint.
     * In a production system, minting would be triggered by off-chain verification processes.
     * @param to The address to mint the RWA token to.
     * @param uri The URI pointing to the token's on-chain metadata (e.g., IPFS hash).
     * @param metadataURI A URI pointing to extensive off-chain legal/physical asset documentation.
     * @return The ID of the newly minted RWA token.
     */
    function issueRWA(address to, string memory uri, string memory metadataURI) external onlyOwner returns (uint256) {
        _tokenIdCounter.increment();
        uint256 newItemId = _tokenIdCounter.current();
        _safeMint(to, newItemId);
        _setTokenURI(newItemId, uri);
        assetMetadataURIs[newItemId] = metadataURI;
        isRWAActive[newItemId] = true; // Mark as active upon issuance

        emit RWAIssued(newItemId, to, uri, metadataURI);
        return newItemId;
    }

    /**
     * @dev Transfers an RWA token. Overrides ERC721's transfer function to emit custom event.
     * Standard ERC721 transferFrom rules apply.
     * @param from The current owner of the RWA.
     * @param to The recipient of the RWA.
     * @param tokenId The ID of the RWA token to transfer.
     */
    function transferFrom(address from, address to, uint256 tokenId) public override {
        super.transferFrom(from, to, tokenId);
        emit RWATransfer(tokenId, from, to);
    }

    /**
     * @dev Allows the owner to toggle the active status of an RWA token.
     * This could be used to temporarily suspend or permanently deactivate an RWA,
     * e.g., if underlying asset issues arise.
     * @param tokenId The ID of the RWA token.
     * @param status The new active status (true for active, false for inactive).
     */
    function toggleRWAStatus(uint256 tokenId, bool status) external onlyOwner {
        require(_exists(tokenId), "RWA token does not exist.");
        isRWAActive[tokenId] = status;
        emit RWAStatusChanged(tokenId, status);
    }

    /**
     * @dev Checks if an RWA token is currently active.
     * @param tokenId The ID of the RWA token.
     * @return True if the RWA is active, false otherwise.
     */
    function getRWAStatus(uint256 tokenId) external view returns (bool) {
        return isRWAActive[tokenId];
    }

    /**
     * @dev Fallback function to accept native token (AVAX on EVM) for accidental transfers.
     */
    receive() external payable {}

    /**
     * @dev Allows the contract owner to recover any ERC20 tokens accidentally sent to this contract.
     * @param tokenAddress The address of the ERC20 token to recover.
     * @param amount The amount of tokens to recover.
     */
    function recoverERC20(address tokenAddress, uint256 amount) external onlyOwner {
        IERC20(tokenAddress).transfer(owner(), amount);
    }

    /**
     * @dev Allows the contract owner to recover native token (AVAX on EVM) accidentally sent to this contract.
     */
    function recoverNativeToken() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
}
