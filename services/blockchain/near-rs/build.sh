# services/blockchain/near-rs/build.sh
#!/bin/bash
set -e

echo "Building NEAR Rust contracts in workspace..."

cargo build --workspace --target wasm32-unknown-unknown --release

declare -A project_wasm_names
project_wasm_names["core-banking"]="bcb_core"
project_wasm_names["did-management"]="bcb_did"
project_wasm_names["account-recovery"]="bcb_acc"

for project_dir in "core-banking" "did-management" "account-recovery"; do
    WASM_FILE_NAME="${project_wasm_names[$project_dir]}"
    UNOPTIMIZED_WASM_PATH="./target/wasm32-unknown-unknown/release/${WASM_FILE_NAME}.wasm"
    OPTIMIZED_WASM_PATH="./res/${WASM_FILE_NAME}.wasm"

    echo "Optimizing ${WASM_FILE_NAME} Wasm binary..."
    if [ -f "$UNOPTIMIZED_WASM_PATH" ]; then
        if command -v wasm-opt &> /dev/null; then
            mkdir -p ./res
            wasm-opt -Oz --strip-debug "$UNOPTIMIZED_WASM_PATH" -o "$OPTIMIZED_WASM_PATH"
            echo "${WASM_FILE_NAME} compiled and optimized to ${OPTIMIZED_WASM_PATH}"
        else
            echo "wasm-opt not found. Skipping optimization for ${WASM_FILE_NAME}. Copying unoptimized Wasm."
            mkdir -p ./res
            cp "$UNOPTIMIZED_WASM_PATH" "$OPTIMIZED_WASM_PATH"
        fi
    else
        echo "Warning: No Wasm file found for ${WASM_FILE_NAME} at ${UNOPTIMIZED_WASM_PATH}"
    fi
done

echo "NEAR Rust contracts compilation and optimization complete."
