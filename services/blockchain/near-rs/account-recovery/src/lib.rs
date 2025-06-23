// services/blockchain/near-rs/account-recovery/src/lib.rs
use near_sdk::{near, BorshStorageKey, PanicOnDefault, AccountId, Promise, Gas, env};
use near_sdk::store::{IterableMap, IterableSet};
use near_sdk::borsh::{self, BorshDeserialize, BorshSerialize};
use near_sdk::ext_contract;
use near_sdk::PromiseResult::*; // FIXED: Changed import to directly bring variants into scope

const MIN_GUARDIANS: u32 = 2;
const RECOVERY_PERIOD_DAYS: u64 = 7;

#[derive(
    Debug,
    BorshDeserialize,
    BorshSerialize
)]
pub struct RecoveryRequest {
    pub account_to_recover: AccountId,
    pub new_public_key: String,
    pub initiated_timestamp: u64,
    pub approvals: IterableSet<AccountId>,
    pub threshold: u32,
}

#[derive(
    near_sdk::serde::Serialize,
    near_sdk::serde::Deserialize,
    Debug,
    PartialEq,
    Clone
)]
#[serde(crate = "near_sdk::serde")]
pub struct RecoveryRequestView {
    pub account_to_recover: AccountId,
    pub new_public_key: String,
    pub initiated_timestamp: u64,
    pub approvals: Vec<AccountId>,
    pub threshold: u32,
}

#[derive(BorshStorageKey, Debug, BorshDeserialize, BorshSerialize)]
pub enum StorageKey {
    UserGuardians,
    ActiveRecoveryRequests,
    RecoveryApprovals { recovery_id_hash: Vec<u8> },
    GuardianSet { account_id_hash: Vec<u8> },
}

#[near(contract_state)]
#[derive(PanicOnDefault)]
pub struct AccountRecovery {
    pub user_guardians: IterableMap<AccountId, IterableSet<AccountId>>,
    pub active_recovery_requests: IterableMap<String, RecoveryRequest>,
}

#[near]
impl AccountRecovery {
    /// Initializes the account recovery contract.
    #[init]
    pub fn new() -> Self {
        Self {
            user_guardians: IterableMap::new(StorageKey::UserGuardians),
            active_recovery_requests: IterableMap::new(StorageKey::ActiveRecoveryRequests),
        }
    }

    /// Allows a user to set or update their list of trusted guardians.
    /// `guardians`: A list of AccountIds that will act as guardians.
    /// Requires a minimum number of guardians.
    pub fn set_guardians(&mut self, guardians: Vec<AccountId>) {
        let signer_id = env::predecessor_account_id();
        assert!(guardians.len() as u32 >= MIN_GUARDIANS,
            "Must provide at least {} guardians.", MIN_GUARDIANS
        );

        let account_id_hash: Vec<u8> = signer_id.as_bytes().to_vec();
        let mut guardian_set = IterableSet::new(
            StorageKey::GuardianSet { account_id_hash }
        );
        for guardian in guardians {
            assert!(signer_id != guardian, "Cannot set self as a guardian.");
            guardian_set.insert(guardian.clone());
        }

        self.user_guardians.insert(signer_id.clone(), guardian_set);
        env::log_str(&format!("Guardians set for: {}", signer_id));
    }

    /// Initiates an account recovery request for a user who has lost access.
    /// This function can be called by anyone, including the lost account itself
    /// (if they regain partial access) or a trusted guardian.
    /// `account_to_recover`: The AccountId of the account that needs recovery.
    /// `new_public_key`: The new public key that should be set for the recovered account.
    /// Returns a unique ID for the recovery request.
    #[payable]
    pub fn initiate_recovery(&mut self, account_to_recover: AccountId, new_public_key: String) -> String {
        assert!(self.user_guardians.contains_key(&account_to_recover),
            "No guardians set for this account."
        );

        let recovery_id = env::sha256_array(&format!("{}{}{}", account_to_recover, new_public_key, env::block_timestamp()).as_bytes())
            .iter()
            .map(|b| format!("{:02x}", b))
            .collect::<String>();

        let guardians_for_account = self.user_guardians.get(&account_to_recover)
            .unwrap_or_else(|| env::panic_str("Guardians not found (should not happen)."));

        let recovery_id_hash: Vec<u8> = recovery_id.clone().into_bytes();
        let request = RecoveryRequest {
            account_to_recover: account_to_recover.clone(),
            new_public_key,
            initiated_timestamp: env::block_timestamp(),
            approvals: IterableSet::new(StorageKey::RecoveryApprovals { recovery_id_hash }),
            threshold: (guardians_for_account.len() / 2 + 1) as u32,
        };

        assert!(!self.active_recovery_requests.contains_key(&recovery_id), "Recovery request ID collision. Please try again.");
        self.active_recovery_requests.insert(recovery_id.clone(), request);

        env::log_str(&format!("Recovery initiated for: {} with ID: {}", account_to_recover, recovery_id));
        recovery_id
    }

    /// Allows a guardian to approve a pending recovery request.
    /// `recovery_id`: The unique ID of the recovery request.
    pub fn approve_recovery(&mut self, recovery_id: String) {
        let signer_id = env::predecessor_account_id();
        let request = self.active_recovery_requests.get_mut(&recovery_id)
            .unwrap_or_else(|| env::panic_str("Recovery request not found."));

        let guardians_for_account = self.user_guardians.get(&request.account_to_recover)
            .unwrap_or_else(|| env::panic_str("Guardians not found for target account."));

        assert!(guardians_for_account.contains(&signer_id), "Caller is not a registered guardian for this account.");
        assert!(!request.approvals.contains(&signer_id), "Guardian has already approved this request.");

        request.approvals.insert(signer_id.clone());

        env::log_str(&format!("Guardian {} approved recovery request ID: {}", signer_id, recovery_id));
    }

    /// Executes the recovery if enough approvals are met and the recovery period has passed.
    /// This function would typically involve a cross-contract call to the NEAR system
    /// contract or a dedicated account management contract to update the public key.
    /// `recovery_id`: The unique ID of the recovery request.
    #[payable]
    pub fn execute_recovery(&mut self, recovery_id: String) -> Promise {
        let request = self.active_recovery_requests.get(&recovery_id)
            .unwrap_or_else(|| env::panic_str("Recovery request not found."));

        assert!(request.approvals.len() as u32 >= request.threshold,
            "Not enough guardian approvals yet."
        );

        let elapsed_time = env::block_timestamp() - request.initiated_timestamp;
        let recovery_period_nanos = RECOVERY_PERIOD_DAYS * 24 * 60 * 60 * 1_000_000_000;
        assert!(elapsed_time >= recovery_period_nanos,
            "Recovery period has not yet passed."
        );

        let account_to_recover_id = request.account_to_recover.clone();
        let new_pk_string = request.new_public_key.clone();

        self.active_recovery_requests.remove(&recovery_id);
        env::log_str(&format!("Executing recovery for account: {}", account_to_recover_id));

        ext_near_account_manager::ext(account_to_recover_id.clone())
            .with_static_gas(Gas::from_tgas(50))
            .update_public_key(new_pk_string)
            .then(
                Self::ext(env::current_account_id())
                    .with_static_gas(Gas::from_tgas(10))
                    .recovery_callback(account_to_recover_id)
            )
    }

    /// Callback function for the recovery execution promise
    #[private]
    pub fn recovery_callback(&mut self, account_id: AccountId) {
        match env::promise_result(0) {
            Successful(_) => { // Handles successful promise results
                env::log_str(&format!("Successfully recovered account: {}", account_id));
            },
            Failed => { // Handles failed promise results
                env::log_str(&format!("Failed to recover account: {}", account_id));
                // TODO: Re-add request if failed, or handle failure as per policy
            },
            // The '_' arm is removed as it's unreachable; PromiseResult will always be Successful or Failed in a callback.
        }
    }

    /// Retrieves the guardians for a specific user.
    /// View function.
    pub fn get_guardians(&self, account_id: AccountId) -> Option<Vec<AccountId>> {
        self.user_guardians.get(&account_id).map(|s| s.iter().cloned().collect())
    }

    /// Retrieves an active recovery request by its ID.
    /// View function.
    pub fn get_recovery_request(&self, recovery_id: String) -> Option<RecoveryRequestView> {
        self.active_recovery_requests.get(&recovery_id).map(|req| {
            RecoveryRequestView {
                account_to_recover: req.account_to_recover.clone(),
                new_public_key: req.new_public_key.clone(),
                initiated_timestamp: req.initiated_timestamp,
                approvals: req.approvals.iter().cloned().collect(),
                threshold: req.threshold,
            }
        })
    }

    /// Gets the number of approvals for a given recovery request.
    /// View function.
    pub fn get_recovery_approvals_count(&self, recovery_id: String) -> u32 {
        self.active_recovery_requests.get(&recovery_id)
            .map(|r| r.approvals.len() as u32)
            .unwrap_or(0)
    }
}

/**
 * @dev External contract interface for a hypothetical account manager contract
 */
#[ext_contract(ext_near_account_manager)]
#[allow(dead_code)] // FIXED: Added allow dead_code for the trait declaration
trait NearAccountManager {
    fn update_public_key(&mut self, new_public_key: String);
}
