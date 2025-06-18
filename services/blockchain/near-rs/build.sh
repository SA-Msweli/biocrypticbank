# services/blockchain/near-rs/build.sh
#!/bin/bash
set -e

echo "Building NEAR Rust contracts in workspace..."

# Build all members of the workspace
cargo build --workspace --target wasm32-unknown-unknown --release

# Optional: Optimize each Wasm binary for smaller size and better performance
# Install wasm-opt if you don't have it: `cargo install wasm-opt`

# Loop through each member and optimize its Wasm output
for project in "core-banking" "did-management" "account-recovery"; do
    WASM_FILE_NAME=$(echo "$project" | tr '-' '_') # Convert kebab-case to snake_case for binary name
    WASM_PATH="./target/wasm32-unknown-unknown/release/${WASM_FILE_NAME}.wasm"
    OPTIMIZED_WASM_PATH="./res/${WASM_FILE_NAME}.wasm" # Output to a 'res' directory

    echo "Optimizing ${project} Wasm binary..."
    if [ -f "$WASM_PATH" ]; then
        if command -v wasm-opt &> /dev/null; then
            mkdir -p ./res
            wasm-opt -Oz --strip-debug "$WASM_PATH" -o "$OPTIMIZED_WASM_PATH"
            echo "${project} compiled and optimized to ${OPTIMIZED_WASM_PATH}"
        else
            echo "wasm-opt not found. Skipping optimization for ${project}. Copying unoptimized Wasm."
            mkdir -p ./res
            cp "$WASM_PATH" "$OPTIMIZED_WASM_PATH"
        fi
    else
        echo "Warning: No Wasm file found for ${project} at ${WASM_PATH}"
    fi
done

echo "NEAR Rust contracts compilation and optimization complete."
