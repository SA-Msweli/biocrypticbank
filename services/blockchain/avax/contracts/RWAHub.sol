// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";

// Chainlink Import for Data Feeds
import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

interface IRWAManager {
    function getAssetInfo(uint256 assetId) external view returns (string memory name, uint256 value, address owner);
    function transferRWA(uint256 assetId, address to) external;
    // TODO: Add other relevant functions like mint, burn, fractionalize, etc. based on RWA logic.
}

/**
 * @title RWAHub
 * @dev Manages Real-World Assets as ERC-721 tokens with metadata and status toggling.
 * Integrates Chainlink Data Feeds for real-time RWA valuation.
 * Uses standard OpenZeppelin ERC721 and ERC721URIStorage for token management.
 * Explicitly replaces _exists checks with ownerOf(tokenId) != address(0) for broader compatibility.
 */
contract RWAHub is Ownable, ERC721, ERC721URIStorage {
    uint256 private _tokenIdCounter;

    mapping(uint256 => string) public assetMetadataURIs;
    mapping(uint256 => bool) public isRWAActive;

    AggregatorV3Interface public rwaValueOracle;

    event RWAIssued(uint256 indexed tokenId, address indexed owner, string uri, string metadataURI);
    event RWAStatusChanged(uint256 indexed tokenId, bool newStatus);
    event RWATransfer(uint256 indexed tokenId, address indexed from, address indexed to);
    event RWAValueOracleUpdated(address indexed newOracleAddress);


    /**
     * @dev Constructor initializes the ERC721 token with a name and symbol.
     * It also allows setting an initial RWA Value Oracle address.
     * @param name The name of the RWA token collection (e.g., "Digital Real Estate").
     * @param symbol The symbol of the RWA token collection (e.g., "DRE").
     * @param _rwaValueOracleAddress The address of the Chainlink AggregatorV3Interface for RWA valuation.
     */
    constructor(string memory name, string memory symbol, address _rwaValueOracleAddress)
        Ownable(msg.sender)
        ERC721(name, symbol)
    {
        _tokenIdCounter = 0;
        setRWAValueOracle(_rwaValueOracleAddress);
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     * This function is explicitly overridden to resolve ambiguity between ERC721 and ERC721URIStorage.
     * It calls the implementation from ERC721URIStorage.
     */
    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     * This function is explicitly overridden to resolve ambiguity between ERC721 and ERC721URIStorage.
     * It calls the implementation from ERC721URIStorage, which correctly handles ERC165.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    /**
     * @dev Allows the owner to set or update the Chainlink Price Feed address for RWA valuation.
     * @param _newRWAValueOracleAddress The address of the AggregatorV3Interface (Price Feed) for RWA values.
     */
    function setRWAValueOracle(address _newRWAValueOracleAddress) public onlyOwner {
        require(_newRWAValueOracleAddress != address(0), "RWA Value Oracle address cannot be zero.");
        rwaValueOracle = AggregatorV3Interface(_newRWAValueOracleAddress);
        emit RWAValueOracleUpdated(_newRWAValueOracleAddress);
    }

    /**
     * @dev Mints a new RWA token and assigns it to an owner. Only the contract owner can mint.
     * @param to The address to mint the RWA token to.
     * @param uri The URI pointing to the token's on-chain metadata (e.g., IPFS hash).
     * @param metadataURI A URI pointing to extensive off-chain legal/physical asset documentation.
     * @return The ID of the newly minted RWA token.
     */
    function issueRWA(address to, string memory uri, string memory metadataURI) external onlyOwner returns (uint256) {
        uint256 newItemId = _tokenIdCounter++;
        _safeMint(to, newItemId);
        _setTokenURI(newItemId, uri);
        assetMetadataURIs[newItemId] = metadataURI;
        isRWAActive[newItemId] = true;

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
    function transferFrom(address from, address to, uint256 tokenId)
        public
        override(ERC721, IERC721)
    {
        super.transferFrom(from, to, tokenId);
        emit RWATransfer(tokenId, from, to);
    }

    /**
     * @dev Allows the owner to toggle the active status of an RWA token.
     * @param tokenId The ID of the RWA token.
     * @param status The new active status (true for active, false for inactive).
     */
    function toggleRWAStatus(uint256 tokenId, bool status) external onlyOwner {
        require(ownerOf(tokenId) != address(0), "RWA token does not exist.");
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
     * @dev Retrieves general information about a specific RWA token, including its value from a Chainlink oracle.
     * @param assetId The ID of the RWA token.
     * @return name The name of the asset (from URI).
     * @return value The value of the asset (from Chainlink oracle).
     * @return owner The current owner of the token.
     */
    function getRWAInfo(uint256 assetId)
        external
        view
        returns (string memory name, uint256 value, address owner)
    {
        require(ownerOf(assetId) != address(0), "RWA token does not exist.");
        require(address(rwaValueOracle) != address(0), "RWA Value Oracle not set.");

        (, int256 rwaPrice, , ,) = rwaValueOracle.latestRoundData();
        uint256 actualValue = uint256(rwaPrice);

        return (tokenURI(assetId), actualValue, ownerOf(assetId));
    }

    /**
     * @dev Fallback function to accept native token (AVAX on EVM) for accidental transfers.
     */
    receive() external payable {}

    /**
     * @dev Allows the contract owner to recover any ERC20 tokens accidentally sent to this contract.
     * This is crucial to prevent funds from being permanently locked.
     * @param tokenAddress The address of the ERC20 token to recover.
     * @param amount The amount of tokens to recover.
     */
    function recoverERC20(address tokenAddress, uint256 amount) external onlyOwner {
        require(tokenAddress != address(0), "Token address cannot be zero.");
        require(amount > 0, "Amount must be greater than 0.");
        (bool success, ) = address(tokenAddress).call(abi.encodeWithSelector(IERC20.transfer.selector, owner(), amount));
        require(success, "Recovery transfer failed.");
    }

    /**
     * @dev Allows the contract owner to recover native token (AVAX on EVM) accidentally sent to this contract.
     */
    function recoverNativeToken() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
}
