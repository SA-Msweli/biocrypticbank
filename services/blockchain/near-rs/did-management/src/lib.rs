// services/blockchain/near-rs/did-management/src/lib.rs
use near_sdk::{near, BorshStorageKey, PanicOnDefault, AccountId, env};
use near_sdk::store::IterableMap;
use near_sdk::borsh::{self, BorshDeserialize, BorshSerialize};

#[derive(
    Debug,
    PartialEq,
    near_sdk::serde::Serialize,
    near_sdk::serde::Deserialize,
    BorshDeserialize,
    BorshSerialize,
    Clone
)]
#[serde(crate = "near_sdk::serde")]
pub struct DidDocument {
    pub owner_id: AccountId,
    pub verifiable_credentials: Vec<String>,
    pub last_updated: u64,
}

#[derive(BorshStorageKey, Debug, BorshDeserialize, BorshSerialize)]
pub enum StorageKey {
    Dids,
}

#[near(contract_state)]
#[derive(PanicOnDefault)]
pub struct DidRegistry {
    dids: IterableMap<AccountId, DidDocument>,
}

#[near]
impl DidRegistry {
    /// Initializes the DID registry contract.
    #[init]
    pub fn new() -> Self {
        Self {
            dids: IterableMap::new(StorageKey::Dids),
        }
    }

    /// Registers a DID for the caller.
    /// A user can only register one DID, linked to their AccountId.
    pub fn register_did(&mut self) -> DidDocument {
        let signer_id = env::predecessor_account_id();
        assert!(!self.dids.contains_key(&signer_id), "DID already registered for this account.");

        let new_did_doc = DidDocument {
            owner_id: signer_id.clone(),
            verifiable_credentials: Vec::new(),
            last_updated: env::block_timestamp(),
        };

        self.dids.insert(signer_id.clone(), new_did_doc);
        env::log_str(&format!("DID registered for: {}", signer_id));
        self.dids.get(&signer_id).unwrap().clone()
    }

    /// Adds a verifiable credential (VC) hash/URI to an existing DID.
    /// Only the DID owner can add VCs to their own DID.
    /// `vc_hash`: A unique identifier or hash of the verifiable credential.
    pub fn add_verifiable_credential(&mut self, vc_hash: String) -> DidDocument {
        let signer_id = env::predecessor_account_id();
        let did_doc = self.dids.get_mut(&signer_id) // FIXED: Removed 'mut'
            .unwrap_or_else(|| env::panic_str("DID not found for this account."));

        assert!(
            !did_doc.verifiable_credentials.contains(&vc_hash),
            "Verifiable credential already exists for this DID."
        );

        did_doc.verifiable_credentials.push(vc_hash);
        did_doc.last_updated = env::block_timestamp();
        env::log_str(&format!("VC added to DID for: {}", signer_id));
        did_doc.clone()
    }

    /// Removes a verifiable credential (VC) hash/URI from an existing DID.
    /// Only the DID owner can remove VCs from their own DID.
    /// `vc_hash`: The unique identifier or hash of the verifiable credential to remove.
    pub fn remove_verifiable_credential(&mut self, vc_hash: String) -> DidDocument {
        let signer_id = env::predecessor_account_id();
        let did_doc = self.dids.get_mut(&signer_id) // FIXED: Removed 'mut'
            .unwrap_or_else(|| env::panic_str("DID not found for this account."));

        let initial_len = did_doc.verifiable_credentials.len();
        did_doc.verifiable_credentials.retain(|h| h != &vc_hash);

        assert!(
            did_doc.verifiable_credentials.len() < initial_len,
            "Verifiable credential not found for this DID."
        );

        did_doc.last_updated = env::block_timestamp();
        env::log_str(&format!("VC removed from DID for: {}", signer_id));
        did_doc.clone()
    }

    /// Retrieves the DidDocument for a given AccountId.
    /// This is a view function and does not modify the state.
    /// `account_id`: The NEAR AccountId whose DID is to be retrieved.
    pub fn get_did_document(&self, account_id: AccountId) -> Option<DidDocument> {
        self.dids.get(&account_id).cloned()
    }

    /// Checks if a DID exists for a given AccountId.
    #[allow(dead_code)]
    pub fn did_exists(&self, account_id: AccountId) -> bool {
        self.dids.contains_key(&account_id)
    }
}
