# services/blockchain/near-rs/deploy.sh
#!/bin/bash
set -e

echo "=== NEAR Rust Contracts Deployment Script ==="
echo "This script will compile your NEAR Rust contracts and deploy them."
echo "Ensure you have 'near-cli' installed and are logged in via 'near login'."

echo "\n--- Step 1: Compiling NEAR Rust contracts ---"
./build.sh

echo "Compilation complete. WASM files are in ./res/."

echo "\nContents of ./res/ directory after build:"
ls -l ./res/ || true

echo "\n--- Step 2: Deploying Contracts ---"

DEPLOYER_ACCOUNT_ID="mcfreack.testnet"
echo "Using deployer account ID: $DEPLOYER_ACCOUNT_ID"

# 1. Deploy DID Management Contract (bcb-did)
# This contract's `new` function takes no arguments.
# NEAR CLI will automatically call 'new' on deploy if no initFunction/initArgs are provided.
echo "\nDeploying DID Management Contract..."
DID_CONTRACT_ACCOUNT_ID="bcb-did.testnet"
DID_WASM_PATH="./res/bcb_did.wasm"
if [ ! -f "$DID_WASM_PATH" ]; then
    echo "Error: WASM file not found for DID Management Contract: $DID_WASM_PATH"
    echo "Please ensure 'build.sh' ran successfully and generated the WASM files."
    exit 1
fi
echo "Deploying $DID_WASM_PATH to $DID_CONTRACT_ACCOUNT_ID..."
near deploy "$DID_CONTRACT_ACCOUNT_ID" "$DID_WASM_PATH" \
  --accountId "$DEPLOYER_ACCOUNT_ID"

echo "DID Management Contract deployed to: $DID_CONTRACT_ACCOUNT_ID"

# 2. Deploy Account Recovery Contract (bcb-rec)
# This contract's `new` function takes no arguments.
# NEAR CLI will automatically call 'new' on deploy if no initFunction/initArgs are provided.
echo "\nDeploying Account Recovery Contract..."
RECOVERY_CONTRACT_ACCOUNT_ID="bcb-rec.testnet"
RECOVERY_WASM_PATH="./res/bcb_acc.wasm"
if [ ! -f "$RECOVERY_WASM_PATH" ]; then
    echo "Error: WASM file not found for Account Recovery Contract: $RECOVERY_WASM_PATH"
    echo "Please ensure 'build.sh' ran successfully and generated the WASM files."
    exit 1
fi
echo "Deploying $RECOVERY_WASM_PATH to $RECOVERY_CONTRACT_ACCOUNT_ID..."
near deploy "$RECOVERY_CONTRACT_ACCOUNT_ID" "$RECOVERY_WASM_PATH" \
  --accountId "$DEPLOYER_ACCOUNT_ID"

echo "Account Recovery Contract deployed to: $RECOVERY_CONTRACT_ACCOUNT_ID"

# 3. Deploy Core Banking Contract (bcb-core) - Two-step deployment
# First, deploy the code.
echo "\nDeploying Core Banking Contract code..."
CORE_BANKING_CONTRACT_ACCOUNT_ID="bcb-core.testnet"
CORE_BANKING_WASM_PATH="./res/bcb_core.wasm"
if [ ! -f "$CORE_BANKING_WASM_PATH" ]; then
    echo "Error: WASM file not found for Core Banking Contract: $CORE_BANKING_WASM_PATH"
    echo "Please ensure 'build.sh' ran successfully and generated the WASM files."
    exit 1
fi
echo "Deploying $CORE_BANKING_WASM_PATH to $CORE_BANKING_CONTRACT_ACCOUNT_ID..."
near deploy "$CORE_BANKING_CONTRACT_ACCOUNT_ID" "$CORE_BANKING_WASM_PATH" \
  --accountId "$DEPLOYER_ACCOUNT_ID"

echo "Core Banking Contract code deployed to: $CORE_BANKING_CONTRACT_ACCOUNT_ID"

# Second, initialize the Core Banking contract via a separate `near call`.
echo "Initializing Core Banking Contract..."
near call "$CORE_BANKING_CONTRACT_ACCOUNT_ID" new \
  "{\"owner_id\": \"$DEPLOYER_ACCOUNT_ID\"}" \
  --accountId "$DEPLOYER_ACCOUNT_ID"

echo "Core Banking Contract initialized."

echo "\n=== NEAR Rust Deployment Complete ==="
echo "Please record these deployed contract IDs for your backend and client configurations:"
echo "DID Management: $DID_CONTRACT_ACCOUNT_ID"
echo "Account Recovery: $RECOVERY_CONTRACT_ACCOUNT_ID"
echo "Core Banking: $CORE_BANKING_CONTRACT_ACCOUNT_ID"
