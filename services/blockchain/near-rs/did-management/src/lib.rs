// services/blockchain/near-rs/did-management/src/lib.rs
use near_sdk::{near, BorshStorageKey, PanicOnDefault, AccountId};
use near_sdk::store::UnorderedMap; // Updated import path for UnorderedMap

// Define the DID structure - derive necessary traits if returned as public view function
// For internal storage in collections, near-sdk handles serialization implicitly.
#[derive(Debug, PartialEq, near_sdk::serde::Serialize, near_sdk::serde::Deserialize)]
#[serde(crate = "near_sdk::serde")] // Important for serde_json
pub struct DidDocument {
    // The DID itself, typically a URN or similar identifier.
    // For simplicity, we'll use AccountId as the DID subject for now.
    pub owner_id: AccountId,
    // A list of Verifiable Credential (VC) hashes or URIs associated with this DID.
    // In a real-world scenario, these would be pointers to off-chain VCs.
    pub verifiable_credentials: Vec<String>,
    // Timestamp of when the DID was created or last updated.
    pub last_updated: u64,
}

// Define a storage key for the LookupMap (new in near-sdk 5.x)
#[derive(BorshStorageKey, Debug)]
pub enum StorageKey {
    Dids,
}

// Define the contract state
#[near(contract_state)]
#[derive(PanicOnDefault)]
pub struct DidRegistry {
    // Maps AccountId to their DidDocument.
    dids: UnorderedMap<AccountId, DidDocument>,
}

#[near]
impl DidRegistry {
    /// Initializes the DID registry contract.
    #[init]
    pub fn new() -> Self {
        Self {
            dids: UnorderedMap::new(StorageKey::Dids), // Use StorageKey for UnorderedMap
        }
    }

    /// Registers a DID for the caller.
    /// A user can only register one DID, linked to their AccountId.
    pub fn register_did(&mut self) -> DidDocument {
        let signer_id = near::env::predecessor_account_id();
        assert!(!self.dids.contains_key(&signer_id), "DID already registered for this account.");

        let new_did_doc = DidDocument {
            owner_id: signer_id.clone(),
            verifiable_credentials: Vec::new(),
            last_updated: near::env::block_timestamp(),
        };

        self.dids.insert(&signer_id, &new_did_doc);
        near::env::log_str(&format!("DID registered for: {}", signer_id));
        new_did_doc
    }

    /// Adds a verifiable credential (VC) hash/URI to an existing DID.
    /// Only the DID owner can add VCs to their own DID.
    /// `vc_hash`: A unique identifier or hash of the verifiable credential.
    pub fn add_verifiable_credential(&mut self, vc_hash: String) -> DidDocument {
        let signer_id = near::env::predecessor_account_id();
        let mut did_doc = self.dids.get(&signer_id)
            .unwrap_or_else(|| near::env::panic_str("DID not found for this account."));

        assert!(
            !did_doc.verifiable_credentials.contains(&vc_hash),
            "Verifiable credential already exists for this DID."
        );

        did_doc.verifiable_credentials.push(vc_hash);
        did_doc.last_updated = near::env::block_timestamp();
        self.dids.insert(&signer_id, &did_doc);
        near::env::log_str(&format!("VC added to DID for: {}", signer_id));
        did_doc
    }

    /// Removes a verifiable credential (VC) hash/URI from an existing DID.
    /// Only the DID owner can remove VCs from their own DID.
    /// `vc_hash`: The unique identifier or hash of the verifiable credential to remove.
    pub fn remove_verifiable_credential(&mut self, vc_hash: String) -> DidDocument {
        let signer_id = near::env::predecessor_account_id();
        let mut did_doc = self.dids.get(&signer_id)
            .unwrap_or_else(|| near::env::panic_str("DID not found for this account."));

        let initial_len = did_doc.verifiable_credentials.len();
        did_doc.verifiable_credentials.retain(|h| h != &vc_hash);

        assert!(
            did_doc.verifiable_credentials.len() < initial_len,
            "Verifiable credential not found for this DID."
        );

        did_doc.last_updated = near::env::block_timestamp();
        self.dids.insert(&signer_id, &did_doc);
        near::env::log_str(&format!("VC removed from DID for: {}", signer_id));
        did_doc
    }

    /// Retrieves the DidDocument for a given AccountId.
    /// This is a view function and does not modify the state.
    /// `account_id`: The NEAR AccountId whose DID is to be retrieved.
    pub fn get_did_document(&self, account_id: AccountId) -> Option<DidDocument> {
        self.dids.get(&account_id)
    }

    /// Checks if a DID exists for a given AccountId.
    #[allow(dead_code)] // Keep for potential future use
    pub fn did_exists(&self, account_id: AccountId) -> bool {
        self.dids.contains_key(&account_id)
    }
}
