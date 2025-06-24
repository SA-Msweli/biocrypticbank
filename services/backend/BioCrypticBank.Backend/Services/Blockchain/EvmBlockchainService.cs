// services/backend/Services/Blockchain/EvmBlockchainService.cs
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Nethereum.Web3;
using Nethereum.Contracts;
using Nethereum.Hex.HexTypes;
using System.Numerics;
using System.Threading.Tasks;
using System.Collections.Generic;
using BioCrypticBank.Backend.Models; // Ensure this namespace is correct

// ABI for AggregatorV3Interface (Chainlink Price Feed)
// Only includes latestRoundData function
public static class AggregatorV3InterfaceABI
{
  public const string ABI = @"
[
    {
        ""inputs"": [],
        ""name"": ""latestRoundData"",
        ""outputs"": [
            { ""internalType"": ""uint80"", ""name"": ""roundId"", ""type"": ""uint80"" },
            { ""internalType"": ""int256"", ""name"": ""answer"", ""type"": ""int256"" },
            { ""internalType"": ""uint256"", ""name"": ""startedAt"", ""type"": ""uint256"" },
            { ""internalType"": ""uint256"", ""name"": ""updatedAt"", ""type"": ""uint256"" },
            { ""internalType"": ""uint80"", ""name"": ""answeredInRound"", ""type"": ""uint80"" }
        ],
        ""stateMutability"": ""view"",
        ""type"": ""function""
    }
]";
}

// ABI for BioCrypticEvmCoreBanking and AvalancheCoreBanking (simplified for relevant MVP functions)
// Only includes transferAndSwapCrossChain for interaction.
// In a full system, you'd generate the full ABI or use specific function ABIs.
public static class CoreBankingContractABI
{
  public const string ABI = @"
[
    {
        ""inputs"": [
            { ""internalType"": ""uint64"", ""name"": ""destinationChainSelector"", ""type"": ""uint64"" },
            { ""internalType"": ""address"", ""name"": ""inputToken"", ""type"": ""address"" },
            { ""internalType"": ""uint256"", ""name"": ""amount"", ""type"": ""uint256"" },
            { ""internalType"": ""address"", ""name"": ""targetOutputToken"", ""type"": ""address"" },
            { ""internalType"": ""address"", ""name"": ""finalRecipient"", ""type"": ""address"" },
            { ""internalType"": ""uint256"", ""name"": ""feeAmount"", ""type"": ""uint256"" }
        ],
        ""name"": ""transferAndSwapCrossChain"",
        ""outputs"": [],
        ""stateMutability"": ""payable"",
        ""type"": ""function""
    }
]";
}

// ABI for IERC20 (simplified for approve function)
public static class ERC20ABI
{
  public const string ABI = @"
[
    {
        ""inputs"": [
            { ""internalType"": ""address"", ""name"": ""spender"", ""type"": ""address"" },
            { ""internalType"": ""uint256"", ""name"": ""amount"", ""type"": ""uint256"" }
        ],
        ""name"": ""approve"",
        ""outputs"": [
            { ""internalType"": ""bool"", ""name"": """", ""type"": ""bool"" }
        ],
        ""stateMutability"": ""nonpayable"",
        ""type"": ""function""
    }
]";
}


namespace BioCrypticBank.Backend.Services.Blockchain
{
  public class EvmBlockchainService : IEvmBlockchainService
  {
    private readonly ILogger<EvmBlockchainService> _logger;
    private readonly IConfiguration _configuration;
    private readonly string _backendPrivateKey;

    // Configuration values
    private readonly Dictionary<string, string> _rpcUrls;
    private readonly Dictionary<string, string> _bankingContractAddresses;
    private readonly Dictionary<string, string> _ccipRouterAddresses;
    private readonly Dictionary<string, string> _uniswapSwapRouterAddresses;

    // Chainlink Price Feed Addresses (Example for Testnets)
    // You MUST replace these with actual testnet addresses.
    private readonly Dictionary<string, string> _priceFeedAddresses = new Dictionary<string, string>
        {
            // For Avalanche Fuji Testnet (ETH/USD example)
            { "Avalanche", "0x546e919fB234dC98F879802c67E7D114675546e9" }, // Placeholder: REPLACE with actual ETH/USD Price Feed on Fuji
            // For Aurora Testnet (ETH/USD example)
            { "Aurora", "0x546e919fB234dC98F879802c67E7D114675546e9" } // Placeholder: REPLACE with actual ETH/USD Price Feed on Aurora
        };

    public EvmBlockchainService(ILogger<EvmBlockchainService> logger, IConfiguration configuration)
    {
      _logger = logger;
      _configuration = configuration;
      _backendPrivateKey = _configuration["BlockchainConfig:BlockchainServicePrivateKey"] ?? throw new ArgumentNullException("BlockchainServicePrivateKey not configured.");

      _rpcUrls = new Dictionary<string, string>
            {
                { "Avalanche", _configuration["BlockchainConfig:AvalancheRpcUrl"] ?? throw new ArgumentNullException("AvalancheRpcUrl not configured.") },
                { "Aurora", _configuration["BlockchainConfig:AuroraRpcUrl"] ?? throw new ArgumentNullException("AuroraRpcUrl not configured.") }
            };

      _bankingContractAddresses = new Dictionary<string, string>
            {
                { "Avalanche", _configuration["BlockchainConfig:AvalancheCoreBankingContractAddress"] ?? throw new ArgumentNullException("AvalancheCoreBankingContractAddress not configured.") },
                { "Aurora", _configuration["BlockchainConfig:AuroraCoreBankingContractAddress"] ?? throw new ArgumentNullException("AuroraCoreBankingContractAddress not configured.") }
            };

      _ccipRouterAddresses = new Dictionary<string, string>
            {
                { "Avalanche", _configuration["BlockchainConfig:ChainlinkCCIPRouterAvalanche"] ?? throw new ArgumentNullException("ChainlinkCCIPRouterAvalanche not configured.") },
                { "Aurora", _configuration["BlockchainConfig:ChainlinkCCIPRouterAurora"] ?? throw new ArgumentNullException("ChainlinkCCIPRouterAurora not configured.") }
            };

      _uniswapSwapRouterAddresses = new Dictionary<string, string>
            {
                { "Avalanche", _configuration["BlockchainConfig:UniswapV3SwapRouterAvalanche"] ?? throw new ArgumentNullException("UniswapV3SwapRouterAvalanche not configured.") },
                { "Aurora", _configuration["BlockchainConfig:UniswapV3SwapRouterAurora"] ?? throw new ArgumentNullException("UniswapV3SwapRouterAurora not configured.") }
            };

      _logger.LogInformation("EvmBlockchainService initialized.");
    }

    private Web3 GetWeb3(string chainName)
    {
      if (!_rpcUrls.ContainsKey(chainName))
      {
        throw new ArgumentException($"RPC URL for chain '{chainName}' not found in configuration.");
      }
      return new Web3(_backendPrivateKey, _rpcUrls[chainName]);
    }

    // --- Chainlink Data Feeds ---
    public async Task<PriceDataResponse> GetLatestPrice(string chainName)
    {
      if (!_priceFeedAddresses.ContainsKey(chainName))
      {
        return new PriceDataResponse { Message = $"Price feed not configured for {chainName} (mocked if in dev)." };
      }

      var web3 = GetWeb3(chainName);
      var priceFeedAddress = _priceFeedAddresses[chainName];

      try
      {
        var contract = web3.Eth.GetContract(AggregatorV3InterfaceABI.ABI, priceFeedAddress);
        var latestRoundDataFunction = contract.GetFunction("latestRoundData");

        // Call the smart contract function
        var result = await latestRoundDataFunction.CallDeserializingToObjectAsync<LatestRoundDataOutput>();

        // Convert price to readable format (e.g., divided by 10^8 for many price feeds)
        // Need to get the decimals from the price feed contract or know them beforehand
        // For MVP, assuming 8 decimals for ETH/USD
        var priceDecimal = (decimal)result.Answer / 1_00000000;

        _logger.LogInformation($"Price for {chainName} from {priceFeedAddress}: {priceDecimal} (Timestamp: {result.UpdatedAt})");

        return new PriceDataResponse
        {
          Price = priceDecimal.ToString(), // Return as string to avoid precision issues
          Timestamp = result.UpdatedAt.ToString(),
          Message = $"Latest price for {chainName} retrieved successfully."
        };
      }
      catch (Exception ex)
      {
        _logger.LogError(ex, $"Error getting latest price for {chainName} from {priceFeedAddress}.");
        return new PriceDataResponse { Message = $"Error retrieving price for {chainName}: {ex.Message}" };
      }
    }

    // DTO for latestRoundData output
    public class LatestRoundDataOutput
    {
      public BigInteger RoundId { get; set; }
      public BigInteger Answer { get; set; }
      public BigInteger StartedAt { get; set; }
      public BigInteger UpdatedAt { get; set; }
      public BigInteger AnsweredInRound { get; set; }
    }


    // --- Cross-Chain Swaps (CCIP) ---
    public async Task<string> InitiateCrossChainSwap(
        string sourceChain,
        string destinationChainSelector,
        string inputTokenAddress,
        BigInteger amount,
        string targetOutputTokenAddress,
        string finalRecipientAddress,
        BigInteger feeAmount
    )
    {
      _logger.LogInformation($"Initiating cross-chain swap on {sourceChain}: Input {amount} of {inputTokenAddress} to swap for {targetOutputTokenAddress} on chain {destinationChainSelector} for recipient {finalRecipientAddress}. Fee: {feeAmount}");

      var web3 = GetWeb3(sourceChain);
      var bankingContractAddress = _bankingContractAddresses[sourceChain];
      var ccipRouterAddress = _ccipRouterAddresses[sourceChain];
      string txHash = string.Empty;

      try
      {
        // Step 1: Approve the Core Banking contract to spend the input token from the Backend's relayer account
        // This is needed if the backend relayer is acting on behalf of the banking contract itself
        // or if the funds are being moved directly from the backend's control.
        // Assuming tokens are already in the banking contract for this call,
        // and the banking contract itself will handle approving the CCIP router.
        // For this MVP, we're assuming the `transferAndSwapCrossChain` function in the
        // Solidity contract handles the approval of the CCIP Router from the banking contract's balance.
        // The Backend's private key is used to sign the call to the banking contract.

        var contract = web3.Eth.GetContract(CoreBankingContractABI.ABI, bankingContractAddress);
        var transferAndSwapFunction = contract.GetFunction("transferAndSwapCrossChain");

        // Estimate gas for the transaction
        var gasEstimate = await transferAndSwapFunction.EstimateGasAsync(
            web3.Eth.TransactionManager.Account.Address, // From address (backend's relayer)
            new HexBigInteger(feeAmount), // Value to send (for CCIP fees)
            null, // Gas Price (let Nethereum handle default or configure)
            null, // Gas (let Nethereum handle estimate)
            new object[] {
                        BigInteger.Parse(destinationChainSelector), // uint64
                        inputTokenAddress, // address
                        amount, // uint256
                        targetOutputTokenAddress, // address
                        finalRecipientAddress, // address
                        feeAmount // uint256 fee (for CCIP)
            }
        );
        _logger.LogInformation($"Estimated gas for transferAndSwapCrossChain: {gasEstimate.Value}");

        // Execute the transaction
        txHash = await transferAndSwapFunction.SendTransactionAsync(
            web3.Eth.TransactionManager.Account.Address, // From address (backend relayer)
            gasEstimate,
            new HexBigInteger(feeAmount), // Value for CCIP fees
            new object[] {
                        BigInteger.Parse(destinationChainSelector), // uint64
                        inputTokenAddress, // address
                        amount, // uint256
                        targetOutputTokenAddress, // address
                        finalRecipientAddress, // address
                        feeAmount // uint256 fee (for CCIP)
            }
        );

        _logger.LogInformation($"Cross-chain swap transaction sent: {txHash}");
        return txHash;
      }
      catch (Exception ex)
      {
        _logger.LogError(ex, $"Error initiating cross-chain swap on {sourceChain}.");
        throw new ApplicationException($"Failed to initiate cross-chain swap: {ex.Message}", ex);
      }
    }

    // --- Other EVM Core Banking (Simulated for MVP) ---
    public async Task<string> GetUserEvmBalance(string chainName, string tokenAddress, string userAddress)
    {
      _logger.LogWarning($"SIMULATING: Get EVM balance for {userAddress} on {chainName} for token {tokenAddress}");
      await Task.Delay(100);
      return "1000000000000000000"; // 1 token (mocked)
    }

    public async Task<string> DepositEvm(string chainName, string tokenAddress, string userAddress, BigInteger amount)
    {
      _logger.LogWarning($"SIMULATING: Deposit EVM {amount} of {tokenAddress} for {userAddress} on {chainName}");
      await Task.Delay(500);
      return Guid.NewGuid().ToString(); // Simulated Transaction ID
    }

    public async Task<string> WithdrawEvm(string chainName, string tokenAddress, string userAddress, BigInteger amount)
    {
      _logger.LogWarning($"SIMULATING: Withdraw EVM {amount} of {tokenAddress} for {userAddress} on {chainName}");
      await Task.Delay(500);
      return Guid.NewGuid().ToString(); // Simulated Transaction ID
    }
  }
}
