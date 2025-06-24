// services/backend/Controllers/ValuesController.cs
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using System.Collections.Generic;
using System.Threading.Tasks;
using Microsoft.Extensions.Configuration;

namespace BioCrypticBank.Backend.Controllers
{
  [ApiController]
  [Route("api/[controller]")]
  public class ValuesController : ControllerBase
  {
    private readonly ILogger<ValuesController> _logger;
    private readonly IConfiguration _configuration;

    // In a real scenario, you'd inject a dedicated BlockchainService here
    // private readonly IBlockchainService _blockchainService;

    public ValuesController(ILogger<ValuesController> logger, IConfiguration configuration)
    {
      _logger = logger;
      _configuration = configuration;
      // _blockchainService = blockchainService; // Inject your blockchain service here
    }

    /// <summary>
    /// A simple GET endpoint to test API responsiveness.
    /// </summary>
    [HttpGet]
    public IEnumerable<string> Get()
    {
      _logger.LogInformation("GET request received for /api/values");
      return new string[] { "Value1", "Value2", "BioCrypticBank API is running!" };
    }

    /// <summary>
    /// Example of how the API might retrieve a blockchain config value.
    /// </summary>
    [HttpGet("blockchain-status")]
    public IActionResult GetBlockchainStatus()
    {
      try
      {
        var avalancheRpc = _configuration["BlockchainConfig:AvalancheRpcUrl"];
        _logger.LogInformation($"Retrieved Avalanche RPC URL: {avalancheRpc}");
        return Ok(new
        {
          Status = "Blockchain config loaded",
          AvalancheRpc = avalancheRpc,
          Message = "This endpoint demonstrates reading blockchain config from appsettings.json. Real blockchain interaction would go here."
        });
      }
      catch (System.Exception ex)
      {
        _logger.LogError(ex, "Error getting blockchain status.");
        return StatusCode(500, "Internal server error.");
      }
    }

    // Example: Placeholder for a future endpoint to initiate a cross-chain swap
    // In the MVP, this might just log the parameters received from the frontend.
    [HttpPost("initiate-cross-chain-swap")]
    public async Task<IActionResult> InitiateCrossChainSwap([FromBody] CrossChainSwapRequest request)
    {
      _logger.LogInformation($"Received cross-chain swap request: From {request.SourceChain} to {request.DestinationChain}, Token {request.InputTokenAddress}, Amount {request.Amount}, Recipient {request.RecipientAddress}");

      // TODO: In a full implementation, this is where the Backend API would:
      // 1. Validate the request.
      // 2. Interact with the Blockchain Layer (e.g., call AvalancheCoreBanking.transferAndSwapCrossChain).
      // 3. Handle transaction signing, gas estimation, and broadcasting.
      // 4. Monitor transaction status and update off-chain database.

      // For MVP, we just simulate success.
      await Task.Delay(100); // Simulate async operation
      return Ok(new { Message = "Cross-chain swap initiated (simulated successfully for MVP).", TransactionId = System.Guid.NewGuid().ToString() });
    }
  }

  // Define a simple request model for the cross-chain swap
  public class CrossChainSwapRequest
  {
    public string SourceChain { get; set; }
    public string DestinationChain { get; set; }
    public string InputTokenAddress { get; set; }
    public string Amount { get; set; } // Use string for amount to handle large numbers/decimals from JS easily
    public string RecipientAddress { get; set; }
  }
}
