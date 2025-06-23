# services/blockchain/aurora/build.sh
#!/bin/bash
set -e

echo "Compiling Aurora Solidity contracts with Hardhat..."

# Navigate to the Aurora project directory if not already there
# This assumes the script is run from the `services/blockchain/aurora/` directory
# or adjusted if run from the monorepo root.
# For simplicity, let's assume it's run from within 'aurora/'
# If run from root, you would do: cd services/blockchain/aurora/

# Install OpenZeppelin and Chainlink contracts using npm
# Installing both @chainlink/contracts (for general interfaces like AggregatorV3)
# and @chainlink/contracts-ccip (for CCIP specific components like Router, Client, Receiver).
echo "Installing OpenZeppelin and Chainlink contracts using npm..."
npm install @openzeppelin/contracts @chainlink/contracts @chainlink/contracts-ccip

# Run Hardhat compilation
npx hardhat compile

echo "Aurora Solidity compilation complete. Artifacts typically in ./artifacts"
