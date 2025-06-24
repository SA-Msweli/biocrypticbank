// services/backend/Models/DidModels.cs
using System.Collections.Generic;

namespace BioCrypticBank.Backend.Models
{
  // Request Models
  public class RegisterDidRequest
  {
    public string AccountId { get; set; }
  }

  public class AddVerifiableCredentialRequest
  {
    public string AccountId { get; set; }
    public string VcHash { get; set; }
  }

  // Response Models
  public class DidDocumentResponse
  {
    public string AccountId { get; set; }
    public List<string> VerifiableCredentials { get; set; } = new List<string>();
    public long LastUpdated { get; set; } // Unix timestamp in milliseconds
    public string Message { get; set; } // For success/error messages
  }
}
