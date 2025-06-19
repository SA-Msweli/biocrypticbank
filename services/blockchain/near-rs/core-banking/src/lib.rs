// services/blockchain/near-rs/core-banking/src/lib.rs

use near_sdk::{
  near, env, BorshStorageKey, PanicOnDefault, AccountId, Promise, NearToken,
  store::LookupMap
};
use near_sdk::borsh::{self, BorshDeserialize, BorshSerialize};

#[derive(BorshSerialize, BorshDeserialize, BorshStorageKey, Debug)]
pub enum StorageKey {
  Balances,
}

#[near(contract_state)]
#[derive(PanicOnDefault)]
pub struct BioCrypticBankCore {
  pub balances: LookupMap<AccountId, NearToken>,
  pub owner_id: AccountId,
}

#[near]
impl BioCrypticBankCore {
  /// Initializes the contract with an owner.
  #[init]
  pub fn new(owner_id: AccountId) -> Self {
      Self {
          balances: LookupMap::new(StorageKey::Balances),
          owner_id,
      }
  }

  /// Allows users to deposit NEAR tokens into their account within the contract.
  #[payable]
  pub fn deposit(&mut self) {
      let account_id = env::predecessor_account_id();
      let deposit_amount: NearToken = env::attached_deposit();
      assert!(deposit_amount.as_yoctonear() > 0, "Attached deposit must be greater than 0.");

      let mut balance_yocto = self.balances.get(&account_id).map_or(0, |b| b.as_yoctonear());
      balance_yocto += deposit_amount.as_yoctonear();
      self.balances.insert(account_id.clone(), NearToken::from_yoctonear(balance_yocto));

      env::log_str(&format!(
          "Deposited {} yoctoNEAR to {}'s account. New balance: {}",
          deposit_amount.as_yoctonear(), account_id, balance_yocto
      ));
  }

  /// Allows users to withdraw NEAR tokens from their account in the contract.
  pub fn withdraw(&mut self, amount: NearToken) -> Promise {
      let account_id = env::predecessor_account_id();
      let mut current_balance_yocto = self.balances.get(&account_id)
          .map_or_else(|| env::panic_str("No balance found for this account."), |b| b.as_yoctonear());

      assert!(amount.as_yoctonear() > 0, "Withdrawal amount must be greater than 0.");
      assert!(current_balance_yocto >= amount.as_yoctonear(), "Insufficient balance for withdrawal.");

      current_balance_yocto -= amount.as_yoctonear();
      self.balances.insert(account_id.clone(), NearToken::from_yoctonear(current_balance_yocto));

      env::log_str(&format!(
          "Withdrawing {} yoctoNEAR from {}'s account. New balance: {}",
          amount.as_yoctonear(), account_id.clone(), current_balance_yocto
      ));

      Promise::new(account_id).transfer(amount)
  }

  /// Retrieves the balance of a specific account.
  pub fn get_balance(&self, account_id: AccountId) -> NearToken {
      *self.balances.get(&account_id).unwrap_or(&NearToken::from_yoctonear(0))
  }

  /// Allows the owner to retrieve accidental deposits or contract fees.
  #[payable]
  pub fn owner_withdraw(&mut self, amount: NearToken) -> Promise {
      assert_eq!(env::predecessor_account_id(), self.owner_id, "Only the owner can call this function.");
      assert!(amount.as_yoctonear() > 0, "Withdrawal amount must be greater than 0.");
      assert!(env::account_balance().as_yoctonear() >= amount.as_yoctonear(), "Contract has insufficient balance.");

      env::log_str(&format!("Owner withdrawing {} yoctoNEAR.", amount.as_yoctonear()));
      Promise::new(self.owner_id.clone()).transfer(amount)
  }
}
