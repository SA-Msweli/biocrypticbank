// services/backend/Controllers/BlockchainController.cs
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using System.Threading.Tasks;
using System.Numerics;
using BioCrypticBank.Backend.Models;
using BioCrypticBank.Backend.Services.Blockchain;

namespace BioCrypticBank.Backend.Controllers
{
  [ApiController]
  [Route("api/[controller]")]
  public class BlockchainController : ControllerBase
  {
    private readonly ILogger<BlockchainController> _logger;
    private readonly INearBlockchainService _nearBlockchainService;
    private readonly IEvmBlockchainService _evmBlockchainService;

    public BlockchainController(
        ILogger<BlockchainController> logger,
        INearBlockchainService nearBlockchainService,
        IEvmBlockchainService evmBlockchainService)
    {
      _logger = logger;
      _nearBlockchainService = nearBlockchainService;
      _evmBlockchainService = evmBlockchainService;
    }

    // --- Chainlink Data Feeds ---
    /// <summary>
    /// Retrieves the latest price for a token from Chainlink Data Feeds on a specified EVM chain.
    /// </summary>
    /// <param name="chainName">The name of the EVM chain (e.g., "Avalanche", "Aurora").</param>
    [HttpGet("price/{chainName}")]
    public async Task<IActionResult> GetLatestPrice(string chainName)
    {
      _logger.LogInformation($"Request for latest price on {chainName}");
      try
      {
        var response = await _evmBlockchainService.GetLatestPrice(chainName);
        if (response.Price != null)
        {
          return Ok(response);
        }
        return NotFound(response); // Price not found or error occurred
      }
      catch (System.Exception ex)
      {
        _logger.LogError(ex, $"Error fetching price for {chainName}.");
        return StatusCode(500, new { Message = $"Internal server error: {ex.Message}" });
      }
    }

    // --- Cross-Chain Swaps (CCIP) ---
    /// <summary>
    /// Initiates a cross-chain token transfer and swap using Chainlink CCIP.
    /// The backend orchestrates the transaction on the source chain.
    /// </summary>
    /// <param name="request">Details of the cross-chain swap.</param>
    [HttpPost("cross-chain-swap")]
    public async Task<IActionResult> InitiateCrossChainSwap([FromBody] CrossChainSwapRequest request)
    {
      _logger.LogInformation($"Received cross-chain swap request: SourceChain={request.SourceChain}, DestinationChain={request.DestinationChain}, InputToken={request.InputTokenAddress}, Amount={request.Amount}, Recipient={request.FinalRecipientAddress}, Fee={request.ChainlinkFeeAmount}, DestSelector={request.DestinationChainSelector}");

      if (!BigInteger.TryParse(request.Amount, out BigInteger amountBigInt))
      {
        return BadRequest(new { Message = "Invalid amount format." });
      }
      if (!BigInteger.TryParse(request.ChainlinkFeeAmount, out BigInteger feeAmountBigInt))
      {
        return BadRequest(new { Message = "Invalid Chainlink fee amount format." });
      }

      try
      {
        // Note: The Backend API's private key (configured in appsettings) will be used to sign
        // the transaction that calls the CoreBanking contract. This assumes the CoreBanking contract
        // is set up to allow the backend's address to call `transferAndSwapCrossChain` (e.g., if the backend
        // is the owner, or a whitelisted relayer). For now, it will be the owner.

        var txHash = await _evmBlockchainService.InitiateCrossChainSwap(
            request.SourceChain,
            request.DestinationChainSelector,
            request.InputTokenAddress,
            amountBigInt,
            request.TargetOutputTokenAddress,
            request.FinalRecipientAddress,
            feeAmountBigInt
        );

        return Ok(new { Message = "Cross-chain swap initiated successfully.", TransactionHash = txHash });
      }
      catch (System.Exception ex)
      {
        _logger.LogError(ex, "Error initiating cross-chain swap.");
        return StatusCode(500, new { Message = $"Internal server error: {ex.Message}" });
      }
    }

    // --- DID Management (NEAR) ---
    /// <summary>
    /// Registers a Decentralized Identifier (DID) for a NEAR account.
    /// </summary>
    /// <param name="request">The request containing the NEAR account ID.</param>
    [HttpPost("did/register")]
    public async Task<IActionResult> RegisterDid([FromBody] RegisterDidRequest request)
    {
      _logger.LogInformation($"Register DID request for AccountId: {request.AccountId}");
      try
      {
        var response = await _nearBlockchainService.RegisterDid(request.AccountId);
        return Ok(response);
      }
      catch (System.Exception ex)
      {
        _logger.LogError(ex, $"Error registering DID for {request.AccountId}.");
        return StatusCode(500, new { Message = $"Internal server error: {ex.Message}" });
      }
    }

    /// <summary>
    /// Adds a verifiable credential hash to an existing DID for a NEAR account.
    /// </summary>
    /// <param name="request">The request containing the NEAR account ID and VC hash.</param>
    [HttpPost("did/add-vc")]
    public async Task<IActionResult> AddVerifiableCredential([FromBody] AddVerifiableCredentialRequest request)
    {
      _logger.LogInformation($"Add VC request for AccountId: {request.AccountId}, VcHash: {request.VcHash}");
      try
      {
        var response = await _nearBlockchainService.AddVerifiableCredential(request.AccountId, request.VcHash);
        return Ok(response);
      }
      catch (System.Exception ex)
      {
        _logger.LogError(ex, $"Error adding VC for {request.AccountId}.");
        return StatusCode(500, new { Message = $"Internal server error: {ex.Message}" });
      }
    }

    /// <summary>
    /// Retrieves the DID document for a given NEAR account ID.
    /// </summary>
    /// <param name="accountId">The NEAR account ID.</param>
    [HttpGet("did/{accountId}")]
    public async Task<IActionResult> GetDidDocument(string accountId)
    {
      _logger.LogInformation($"Get DID document request for AccountId: {accountId}");
      try
      {
        var response = await _nearBlockchainService.GetDidDocument(accountId);
        if (response.VerifiableCredentials != null || response.Message.Contains("found")) // Simple check for a "found" DID
        {
          return Ok(response);
        }
        return NotFound(response);
      }
      catch (System.Exception ex)
      {
        _logger.LogError(ex, $"Error retrieving DID document for {accountId}.");
        return StatusCode(500, new { Message = $"Internal server error: {ex.Message}" });
      }
    }

    // --- NEAR Account Recovery ---
    /// <summary>
    /// Initiates an account recovery request for a NEAR account.
    /// </summary>
    /// <param name="request">The request containing the account to recover and new public key.</param>
    [HttpPost("near-recovery/initiate")]
    public async Task<IActionResult> InitiateNearRecovery([FromBody] InitiateRecoveryRequest request)
    {
      _logger.LogInformation($"Initiate NEAR recovery request for Account: {request.AccountToRecover}");
      try
      {
        var response = await _nearBlockchainService.InitiateRecovery(request.AccountToRecover, request.NewPublicKey);
        return Ok(response);
      }
      catch (System.Exception ex)
      {
        _logger.LogError(ex, $"Error initiating NEAR recovery for {request.AccountToRecover}.");
        return StatusCode(500, new { Message = $"Internal server error: {ex.Message}" });
      }
    }

    /// <summary>
    /// Retrieves the details of a pending NEAR account recovery request.
    /// </summary>
    /// <param name="recoveryId">The ID of the recovery request.</param>
    [HttpGet("near-recovery/{recoveryId}")]
    public async Task<IActionResult> GetNearRecoveryRequest(string recoveryId)
    {
      _logger.LogInformation($"Get NEAR recovery request for ID: {recoveryId}");
      try
      {
        var response = await _nearBlockchainService.GetRecoveryRequest(recoveryId);
        if (response.AccountToRecover != null) // If accountToRecover is set, assume request found
        {
          return Ok(response);
        }
        return NotFound(response);
      }
      catch (System.Exception ex)
      {
        _logger.LogError(ex, $"Error retrieving NEAR recovery request for ID: {recoveryId}.");
        return StatusCode(500, new { Message = $"Internal server error: {ex.Message}" });
      }
    }

    // --- Generic Balance Endpoints ---
    /// <summary>
    /// Retrieves the balance for a given account/address and token on a specified blockchain.
    /// </summary>
    /// <param name="request">Balance request details.</param>
    [HttpGet("balance")]
    public async Task<IActionResult> GetBalance([FromQuery] GetBalanceRequest request)
    {
      _logger.LogInformation($"Get balance request: Chain={request.ChainName}, Account/Address={request.AccountIdOrAddress}, Token={request.TokenAddress}");
      try
      {
        string balance = "0";
        if (request.ChainName.ToLower() == "near")
        {
          balance = await _nearBlockchainService.GetNearBalance(request.AccountIdOrAddress);
        }
        else if (request.ChainName.ToLower() == "avalanche" || request.ChainName.ToLower() == "aurora")
        {
          // For MVP, EVM balance is also simulated
          balance = await _evmBlockchainService.GetUserEvmBalance(request.ChainName, request.TokenAddress, request.AccountIdOrAddress);
        }
        else
        {
          return BadRequest(new { Message = "Unsupported chain name." });
        }

        return Ok(new BalanceResponse
        {
          AccountIdOrAddress = request.AccountIdOrAddress,
          TokenAddress = request.TokenAddress,
          Balance = balance,
          Message = $"Balance retrieved for {request.AccountIdOrAddress} on {request.ChainName}."
        });
      }
      catch (System.Exception ex)
      {
        _logger.LogError(ex, $"Error retrieving balance for {request.AccountIdOrAddress}.");
        return StatusCode(500, new { Message = $"Internal server error: {ex.Message}" });
      }
    }
  }
}
