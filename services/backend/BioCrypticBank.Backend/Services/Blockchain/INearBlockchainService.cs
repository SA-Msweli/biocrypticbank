// services/backend/Services/Blockchain/INearBlockchainService.cs
using System.Threading.Tasks;
using BioCrypticBank.Backend.Models; // Ensure this namespace is correct

namespace BioCrypticBank.Backend.Services.Blockchain
{
  public interface INearBlockchainService
  {
    // DID Management
    Task<DidDocumentResponse> RegisterDid(string accountId);
    Task<DidDocumentResponse> AddVerifiableCredential(string accountId, string vcHash);
    Task<DidDocumentResponse> GetDidDocument(string accountId);

    // Core Banking (NEAR Native)
    Task<string> GetNearBalance(string accountId); // Returns balance as a string
    Task<string> DepositNear(string accountId, string amountYoctoNear); // Simulates deposit
    Task<string> WithdrawNear(string accountId, string amountYoctoNear); // Simulates withdrawal

    // Account Recovery (NEAR) - for MVP, mostly read/simulate
    Task<RecoveryRequestResponse> InitiateRecovery(string accountToRecover, string newPublicKey);
    Task<RecoveryRequestResponse> GetRecoveryRequest(string recoveryId);
  }
}
