// services/backend/Services/Blockchain/IEvmBlockchainService.cs
using System.Numerics;
using System.Threading.Tasks;
using BioCrypticBank.Backend.Models; // Ensure this namespace is correct

namespace BioCrypticBank.Backend.Services.Blockchain
{
  public interface IEvmBlockchainService
  {
    // Chainlink Data Feeds
    Task<PriceDataResponse> GetLatestPrice(string chainName);

    // Cross-Chain Swaps (CCIP)
    Task<string> InitiateCrossChainSwap(
        string sourceChain,
        string destinationChainSelector,
        string inputTokenAddress,
        BigInteger amount,
        string targetOutputTokenAddress,
        string finalRecipientAddress,
        BigInteger feeAmount // Amount of LINK or native token for fees
    );

    // Other EVM Core Banking (Optional for MVP, but good for completeness)
    Task<string> GetUserEvmBalance(string chainName, string tokenAddress, string userAddress);
    Task<string> DepositEvm(string chainName, string tokenAddress, string userAddress, BigInteger amount);
    Task<string> WithdrawEvm(string chainName, string tokenAddress, string userAddress, BigInteger amount);
  }
}
