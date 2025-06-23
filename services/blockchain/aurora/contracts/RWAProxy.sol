// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IRWAManager {
    function getAssetInfo(uint256 assetId) external view returns (string memory name, uint256 value, address owner);
    function transferRWA(uint256 assetId, address to) external;
    // TODO: Add other relevant functions like mint, burn, fractionalize, etc. based on RWA logic.
}

/**
 * @title RWAProxy
 * @dev This contract serves as a proxy or gateway for interacting with a Real-World Asset (RWA)
 * tokenization manager contract on the Aurora EVM.
 * It abstracts away the direct interaction with a complex RWA management system.
 * The owner of this proxy contract can set the address of the RWA Manager.
 */
contract RWAProxy is Ownable {
    IRWAManager public rwaManager;

    event RWAManagerUpdated(address indexed newManager);
    event RWATransferInitiated(uint256 indexed assetId, address indexed from, address indexed to);

    /**
     * @dev Constructor sets the initial RWA Manager address.
     * @param _rwaManagerAddress The address of the RWA Manager contract.
     */
    constructor(address _rwaManagerAddress) Ownable(msg.sender) {
        setRWAManager(_rwaManagerAddress);
    }

    /**
     * @dev Allows the owner to set or update the address of the RWA Manager contract.
     * This is a critical administrative function.
     * @param _newRWAManagerAddress The new address for the RWA Manager contract.
     */
    function setRWAManager(address _newRWAManagerAddress) public onlyOwner {
        require(_newRWAManagerAddress != address(0), "RWA Manager address cannot be zero.");
        rwaManager = IRWAManager(_newRWAManagerAddress);
        emit RWAManagerUpdated(_newRWAManagerAddress);
    }

    /**
     * @dev Initiates a transfer of a tokenized RWA via the RWA Manager contract.
     * @param assetId The unique ID of the RWA token to transfer.
     * @param to The recipient's address.
     */
    function initiateRWATransfer(uint256 assetId, address to) external onlyOwner {
        require(address(rwaManager) != address(0), "RWA Manager not set.");
        require(to != address(0), "Recipient address cannot be zero.");
        rwaManager.transferRWA(assetId, to);
        emit RWATransferInitiated(assetId, address(this), to);
    }

    /**
     * @dev Retrieves information about a specific RWA token.
     * @param assetId The unique ID of the RWA token.
     * @return name The name of the asset.
     * @return value The value of the asset.
     * @return owner The owner of the asset.
     */
    function getRWAInfo(uint256 assetId) external view returns (string memory name, uint256 value, address owner) {
        require(address(rwaManager) != address(0), "RWA Manager not set.");
        return rwaManager.getAssetInfo(assetId);
    }

    /**
     * @dev Fallback function to accept native token (ETH on EVM) for accidental transfers.
     */
    receive() external payable {}

    /**
     * @dev Allows the contract owner to recover any ERC20 tokens accidentally sent to this contract.
     * @param tokenAddress The address of the ERC20 token to recover.
     * @param amount The amount of tokens to recover.
     */
    function recoverERC20(address tokenAddress, uint256 amount) external onlyOwner {
        require(tokenAddress != address(0), "Token address cannot be zero.");
        require(amount > 0, "Amount must be greater than 0.");
        IERC20(tokenAddress).transfer(owner(), amount);
    }

    /**
     * @dev Allows the contract owner to recover native token (ETH on EVM) accidentally sent to this contract.
     */
    function recoverNativeToken() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
}
