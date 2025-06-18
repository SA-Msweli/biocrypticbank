// services/blockchain/near-rs/account-recovery/src/lib.rs
use near_sdk::{near, BorshStorageKey, PanicOnDefault, AccountId, Promise, Gas};
use near_sdk::store::{LookupMap, UnorderedSet}; // Updated import paths for LookupMap and UnorderedSet

// Constants for recovery configuration
const MIN_GUARDIANS: u32 = 2; // Minimum number of guardians required for recovery
const RECOVERY_PERIOD_DAYS: u66 = 7; // Time in days before a recovery request can be executed (in days)

// Define the recovery request state
#[derive(
    Debug,
    PartialEq,
    near_sdk::serde::Serialize,
    near_sdk::serde::Deserialize,
    near_sdk::borsh::BorshDeserialize, // Keep Borsh for internal storage within collections
    near_sdk::borsh::BorshSerialize    // Keep Borsh for internal storage within collections
)]
#[serde(crate = "near_sdk::serde")]
pub struct RecoveryRequest {
    pub account_to_recover: AccountId,
    pub new_public_key: String, // The new public key to set for the account
    pub initiated_timestamp: u64, // Timestamp when the request was initiated (nanoseconds)
    pub approvals: UnorderedSet<AccountId>, // Guardians who have approved the request
    pub threshold: u32, // Number of approvals required for this specific request
}

// Define storage keys for LookupMap and UnorderedSet
#[derive(BorshStorageKey, Debug)]
pub enum StorageKey {
    UserGuardians,
    ActiveRecoveryRequests,
    // Changed BorshBuffer to Vec<u8> for storage key prefixes
    RecoveryApprovals { recovery_id_hash: Vec<u8> },
    GuardianSet { account_id_hash: Vec<u8> },
}

// Define the contract state
#[near(contract_state)]
#[derive(PanicOnDefault)]
pub struct AccountRecovery {
    // Maps AccountId to a list of their trusted guardians.
    pub user_guardians: LookupMap<AccountId, UnorderedSet<AccountId>>,
    // Maps a unique recovery ID (e.g., hash of request) to a RecoveryRequest.
    pub active_recovery_requests: LookupMap<String, RecoveryRequest>,
}

#[near]
impl AccountRecovery {
    /// Initializes the account recovery contract.
    #[init]
    pub fn new() -> Self {
        Self {
            user_guardians: LookupMap::new(StorageKey::UserGuardians),
            active_recovery_requests: LookupMap::new(StorageKey::ActiveRecoveryRequests),
        }
    }

    /// Allows a user to set or update their list of trusted guardians.
    /// `guardians`: A list of AccountIds that will act as guardians.
    /// Requires a minimum number of guardians.
    pub fn set_guardians(&mut self, guardians: Vec<AccountId>) {
        let signer_id = near::env::predecessor_account_id();
        assert!(guardians.len() as u32 >= MIN_GUARDIANS,
            &format!("Must provide at least {} guardians.", MIN_GUARDIANS)
        );

        // Convert AccountId to bytes for storage key prefix
        let account_id_hash: Vec<u8> = signer_id.as_bytes().to_vec();
        let mut guardian_set = UnorderedSet::new(
            StorageKey::GuardianSet { account_id_hash }
        );
        for guardian in guardians {
            assert!(signer_id != guardian, "Cannot set self as a guardian.");
            guardian_set.insert(&guardian);
        }

        self.user_guardians.insert(&signer_id, &guardian_set);
        near::env::log_str(&format!("Guardians set for: {}", signer_id));
    }

    /// Initiates an account recovery request for a user who has lost access.
    /// This function can be called by anyone, including the lost account itself
    /// (if they regain partial access) or a trusted guardian.
    /// `account_to_recover`: The AccountId of the account that needs recovery.
    /// `new_public_key`: The new public key that should be set for the recovered account.
    /// Returns a unique ID for the recovery request.
    #[payable] // Might require a small deposit to prevent spam
    pub fn initiate_recovery(&mut self, account_to_recover: AccountId, new_public_key: String) -> String {
        assert!(self.user_guardians.contains_key(&account_to_recover),
            "No guardians set for this account."
        );

        // Generate a unique ID for the recovery request
        let recovery_id = near::env::sha256_array(&format!("{}{}{}", account_to_recover, new_public_key, near::env::block_timestamp()).as_bytes())
            .iter()
            .map(|b| format!("{:02x}", b))
            .collect::<String>();

        let guardians_for_account = self.user_guardians.get(&account_to_recover)
            .unwrap_or_else(|| near::env::panic_str("Guardians not found (should not happen)."));

        // Convert recovery_id string to bytes for storage key prefix
        let recovery_id_hash: Vec<u8> = recovery_id.clone().into_bytes();
        let request = RecoveryRequest {
            account_to_recover: account_to_recover.clone(),
            new_public_key,
            initiated_timestamp: near::env::block_timestamp(),
            approvals: UnorderedSet::new(StorageKey::RecoveryApprovals { recovery_id_hash }),
            threshold: (guardians_for_account.len() / 2 + 1) as u32, // Simple majority threshold
        };

        assert!(!self.active_recovery_requests.contains_key(&recovery_id), "Recovery request ID collision. Please try again.");
        self.active_recovery_requests.insert(&recovery_id, &request);

        near::env::log_str(&format!("Recovery initiated for: {} with ID: {}", account_to_recover, recovery_id));
        recovery_id
    }

    /// Allows a guardian to approve a pending recovery request.
    /// `recovery_id`: The unique ID of the recovery request.
    pub fn approve_recovery(&mut self, recovery_id: String) {
        let signer_id = near::env::predecessor_account_id();
        let mut request = self.active_recovery_requests.get(&recovery_id)
            .unwrap_or_else(|| near::env::panic_str("Recovery request not found."));

        let guardians_for_account = self.user_guardians.get(&request.account_to_recover)
            .unwrap_or_else(|| near::env::panic_str("Guardians not found for target account."));

        assert!(guardians_for_account.contains(&signer_id), "Caller is not a registered guardian for this account.");
        assert!(!request.approvals.contains(&signer_id), "Guardian has already approved this request.");

        request.approvals.insert(&signer_id);
        self.active_recovery_requests.insert(&recovery_id, &request);

        near::env::log_str(&format!("Guardian {} approved recovery request ID: {}", signer_id, recovery_id));
    }

    /// Executes the recovery if enough approvals are met and the recovery period has passed.
    /// This function would typically involve a cross-contract call to the NEAR system
    /// contract or a dedicated account management contract to update the public key.
    /// `recovery_id`: The unique ID of the recovery request.
    #[payable] // May require a small fee
    pub fn execute_recovery(&mut self, recovery_id: String) -> Promise {
        let request = self.active_recovery_requests.get(&recovery_id)
            .unwrap_or_else(|| near::env::panic_str("Recovery request not found."));

        assert!(request.approvals.len() as u32 >= request.threshold,
            "Not enough guardian approvals yet."
        );

        let elapsed_time = near::env::block_timestamp() - request.initiated_timestamp;
        let recovery_period_nanos = RECOVERY_PERIOD_DAYS * 24 * 60 * 60 * 1_000_000_000;
        assert!(elapsed_time >= recovery_period_nanos,
            "Recovery period has not yet passed."
        );

        let account_to_recover_id = request.account_to_recover.clone();
        let new_pk_string = request.new_public_key.clone();

        // Remove the active request once executed
        self.active_recovery_requests.remove(&recovery_id);
        near::env::log_str(&format!("Executing recovery for account: {}", account_to_recover_id));

        // This is a placeholder for the actual key update logic.
        // In a real scenario, this would likely involve a cross-contract call
        // to a privileged NEAR system contract or a specially designed
        // account management contract to update the full access key.

        ext_near_account_manager::ext(account_to_recover_id.clone())
            .with_static_gas(Gas::from_tgas(50)) // Allocate specific gas for the promise
            .update_public_key(new_pk_string)
            .then(
                Self::ext(near::env::current_account_id())
                    .with_static_gas(Gas::from_tgas(10)) // Allocate specific gas for callback
                    .recovery_callback(account_to_recover_id)
            )
    }

    // Callback function for the recovery execution promise
    #[private] // Only callable by the contract itself
    pub fn recovery_callback(&mut self, account_id: AccountId) {
        match near::env::promise_result(0) {
            near_sdk::PromiseResult::Not => near::env::panic_str("Promise not ready."),
            near_sdk::PromiseResult::Successful(_) => {
                near::env::log_str(&format!("Successfully recovered account: {}", account_id));
            },
            near_sdk::PromiseResult::Failed => {
                near::env::log_str(&format!("Failed to recover account: {}", account_id));
                // Re-add request if failed, or handle failure as per policy
            },
        }
    }

    /// Retrieves the guardians for a specific user.
    /// View function.
    pub fn get_guardians(&self, account_id: AccountId) -> Option<Vec<AccountId>> {
        self.user_guardians.get(&account_id).map(|s| s.to_vec())
    }

    /// Retrieves an active recovery request by its ID.
    /// View function.
    pub fn get_recovery_request(&self, recovery_id: String) -> Option<&RecoveryRequest> {
        self.active_recovery_requests.get(&recovery_id)
    }

    /// Gets the number of approvals for a given recovery request.
    /// View function.
    pub fn get_recovery_approvals_count(&self, recovery_id: String) -> u32 {
        self.active_recovery_requests.get(&recovery_id)
            .map(|r| r.approvals.len() as u32)
            .unwrap_or(0)
    }
}

// External contract interface for a hypothetical account manager contract
#[ext_contract]
trait NearAccountManager {
    fn update_public_key(&mut self, new_public_key: String);
}
