# services/blockchain/avax/build.sh
#!/bin/bash
set -e

echo "Building BioCrypticBank Avalanche contracts..."

# This script expects to be run from directly within the 'services/blockchain/avax' directory.
# No 'cd' command is needed here if it's executed from the correct project root.

# Check if npm is available
if ! command -v npm &> /dev/null
then
    echo "Error: npm command not found. Please ensure Node.js and npm are installed."
    exit 1
fi

# Step 1: Install OpenZeppelin contracts using npm (for Hardhat)
# This will place them in the 'node_modules/' directory, allowing imports like "@openzeppelin/contracts/..."
echo "Installing OpenZeppelin contracts using npm..."
npm install @openzeppelin/contracts

# Step 2: Clean Hardhat's cache to ensure a fresh compilation
echo "Cleaning Hardhat cache..."
npx hardhat clean

# Step 3: Build the Solidity contracts using Hardhat
echo "Compiling Avalanche Solidity contracts with Hardhat..."
npx hardhat compile

echo "Avalanche contracts compilation complete. Artifacts will be in ./artifacts directory (default for Hardhat)."
