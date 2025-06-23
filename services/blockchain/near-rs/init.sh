# services/blockchain/near-rs/init.sh
#!/bin/bash
set -e

echo "=== NEAR Rust Contracts Initialization Script ==="
echo "This script will initialize the deployed NEAR Rust contracts that require a 'new' call."
echo "Ensure you have 'near-cli' installed and are logged in via 'near login'."

# Define the NEAR account ID that will be used to initialize the contracts
DEPLOYER_ACCOUNT_ID="mcfreack.testnet"
echo "Using deployer account ID: $DEPLOYER_ACCOUNT_ID"

# 1. Initialize DID Management Contract (bcb-did)
# The `new` function of bcb-did.testnet takes no arguments.
echo "\nInitializing DID Management Contract (bcb-did.testnet)..."
DID_CONTRACT_ACCOUNT_ID="bcb-did.testnet"
near call "$DID_CONTRACT_ACCOUNT_ID" new --accountId "$DEPLOYER_ACCOUNT_ID"

echo "DID Management Contract initialized."

# 2. Initialize Account Recovery Contract (bcb-acc)
# The `new` function of bcb-acc.testnet takes no arguments.
echo "\nInitializing Account Recovery Contract (bcb-acc.testnet)..."
RECOVERY_CONTRACT_ACCOUNT_ID="bcb-rec.testnet"
near call "$RECOVERY_CONTRACT_ACCOUNT_ID" new --accountId "$DEPLOYER_ACCOUNT_ID"

echo "Account Recovery Contract initialized."

echo "\nNEAR Rust Contracts Initialization Complete."
