// services/backend/Models/BlockchainModels.cs
using System.Numerics;
using System.Collections.Generic; // Added for List<string> in RecoveryRequestResponse

namespace BioCrypticBank.Backend.Models
{
  // General Blockchain Models (for cross-chain swap, price data)
  public class CrossChainSwapRequest
  {
    public string SourceChain { get; set; } // e.g., "Avalanche"
    public string DestinationChain { get; set; } // e.g., "Aurora"
    public string InputTokenAddress { get; set; }
    public string Amount { get; set; } // Use string to handle BigInteger conversion at service level
    public string TargetOutputTokenAddress { get; set; }
    public string FinalRecipientAddress { get; set; }
    public string ChainlinkFeeAmount { get; set; } // Use string to handle BigInteger conversion
    public string DestinationChainSelector { get; set; } // Chainlink Chain Selector for the destination
  }

  public class PriceDataResponse
  {
    public string Price { get; set; } // Use string to handle large decimal values
    public string Timestamp { get; set; } // Unix timestamp
    public string Message { get; set; }
  }

  // NEAR Account Recovery Models
  public class InitiateRecoveryRequest
  {
    public string AccountToRecover { get; set; }
    public string NewPublicKey { get; set; }
  }

  public class GetRecoveryRequestById
  {
    public string RecoveryId { get; set; }
  }

  public class RecoveryRequestResponse
  {
    public string RecoveryId { get; set; }
    public string AccountToRecover { get; set; }
    public string NewPublicKey { get; set; }
    public long InitiatedTimestamp { get; set; }
    public List<string> Approvals { get; set; } = new List<string>();
    public uint Threshold { get; set; }
    public string Message { get; set; }
  }

  // Generic Balance Request/Response
  public class GetBalanceRequest
  {
    public string ChainName { get; set; } // "Near", "Avalanche", "Aurora"
    public string AccountIdOrAddress { get; set; }
    public string TokenAddress { get; set; } // Relevant for EVM, can be null for NEAR native
  }

  public class BalanceResponse
  {
    public string AccountIdOrAddress { get; set; }
    public string TokenAddress { get; set; }
    public string Balance { get; set; } // As string to handle large numbers
    public string Message { get; set; }
  }
}
