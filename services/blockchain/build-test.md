BioCrypticBank Smart Contract Compilation and Testing Guide
This guide outlines the steps and commands needed to compile and test the smart contracts for each blockchain project within your services/blockchain/ directory.

1. near-rs/ (Native NEAR Rust Contracts)
Prerequisites
Rustup: The Rust toolchain installer.

curl --proto '=https' --tlsv1.2 -sY https://sh.rustup.rs | sh
source $HOME/.cargo/env

wasm32-unknown-unknown target: Needed for compiling Rust to WebAssembly.

rustup target add wasm32-unknown-unknown

cargo install cargo-generate: To generate new NEAR Rust projects (optional, but useful).

cargo install cargo-generate

cargo install near-cli: NEAR CLI for deployment and interaction (optional, but useful).

npm install -g near-cli

cargo install near-sdk-rs: The NEAR Rust SDK (usually included as a dependency in Cargo.toml).

Compilation (build.sh)
Navigate to the services/blockchain/near-rs/ directory.

cd services/blockchain/near-rs/

Create a build.sh script (or run commands directly):

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

Then make it executable and run:

chmod +x build.sh
./build.sh

Testing
NEAR Rust contracts are typically tested using Rust's built-in cargo test functionality for unit tests and near-sdk-sim or workspaces-rs for integration/simulation tests.

Navigate to the services/blockchain/near-rs/ directory.

cd services/blockchain/near-rs/

Run unit tests:

# services/blockchain/near-rs/test.sh (for unit tests)
#!/bin/bash
set -e

echo "Running NEAR Rust unit tests..."
cargo test --workspace # Or `cargo test` if only testing this crate
echo "NEAR Rust unit tests complete."

Make it executable and run:

chmod +x test.sh
./test.sh

2. aurora/ (Aurora Solidity Contracts) and avax/ (Avalanche Solidity Contracts)
Both Aurora and Avalanche's C-Chain are EVM compatible, so the compilation and testing steps are very similar, using standard Solidity development tools.

Prerequisites (for both aurora/ and avax/)
Node.js & npm/yarn:

sudo apt update
sudo apt install nodejs npm # For npm
# npm install -g yarn # For yarn

Hardhat OR Foundry:

Hardhat (recommended for beginners):

npm install --save-dev hardhat

Foundry (more advanced, often preferred):

curl -L https://foundry.paradigm.xyz | bash
foundryup

OpenZeppelin Contracts: Your contracts use OpenZeppelin.

# For Hardhat projects
npm install @openzeppelin/contracts

# For Foundry projects
forge install OpenZeppelin/openzeppelin-contracts

Compilation (build.sh)
Navigate to the respective project directory (services/blockchain/aurora/ or services/blockchain/avax/).

cd services/blockchain/aurora/ # Or services/blockchain/avax/

Using Hardhat:
(Ensure hardhat.config.js is set up in the root of the project with network config)

# services/blockchain/aurora/build.sh OR services/blockchain/avax/build.sh
#!/bin/bash
set -e

echo "Compiling Solidity contracts with Hardhat..."
npx hardhat compile
echo "Solidity compilation complete. Artifacts in ./artifacts"

Using Foundry:
(Ensure foundry.toml is set up in the root of the project)

# services/blockchain/aurora/build.sh OR services/blockchain/avax/build.sh
#!/bin/bash
set -e

echo "Compiling Solidity contracts with Foundry..."
forge build
echo "Solidity compilation complete. Artifacts in ./out"

Then make it executable and run:

chmod +x build.sh
./build.sh

Testing
Navigate to the respective project directory (services/blockchain/aurora/ or services/blockchain/avax/).

cd services/blockchain/aurora/ # Or services/blockchain/avax/

Using Hardhat:
(Tests typically in test/ directory, e.g., test/AaveIntegration.test.js)

# services/blockchain/aurora/test.sh OR services/blockchain/avax/test.sh
#!/bin/bash
set -e

echo "Running Solidity tests with Hardhat..."
npx hardhat test
echo "Hardhat tests complete."

Using Foundry:
(Tests typically in test/ directory, e.g., test/AaveIntegration.t.sol)

# services/blockchain/aurora/test.sh OR services/blockchain/avax/test.sh
#!/bin/bash
set -e

echo "Running Solidity tests with Foundry..."
forge test
echo "Foundry tests complete."

Then make it executable and run:

chmod +x test.sh
./test.sh

Example Foundry Test (avax/test/AvalancheCoreBanking.t.sol)

// avax/test/AvalancheCoreBanking.t.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../contracts/AvalancheCoreBanking.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol"; // For a mock ERC20

// Mock ERC20 contract for testing purposes
contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol, uint256 initialSupply) ERC20(name, symbol) {
        _mint(msg.sender, initialSupply);
    }

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}


contract AvalancheCoreBankingTest is Test {
    AvalancheCoreBanking public coreBanking;
    MockERC20 public mockUSDC; // Mock token to simulate USDC
    address public deployer;
    address public user1;
    address public user2;

    function setUp() public {
        deployer = vm.addr(1); // Mocks the deployer address
        user1 = vm.addr(2);    // Mocks user1 address
        user2 = vm.addr(3);    // Mocks user2 address

        // Deploy Core Banking contract from deployer
        vm.prank(deployer);
        coreBanking = new AvalancheCoreBanking();

        // Deploy Mock USDC token and mint some to users
        vm.prank(deployer);
        mockUSDC = new MockERC20("Mock USDC", "mUSDC", 1_000_000 * 1e6); // 1M USDC, 6 decimals

        // Toggle support for mockUSDC in the banking contract
        vm.prank(deployer);
        coreBanking.toggleTokenSupport(address(mockUSDC), true);

        // Give some mock USDC to user1 and user2 for testing
        mockUSDC.mint(user1, 10_000 * 1e6);
        mockUSDC.mint(user2, 5_000 * 1e6);
    }

    function testDeposit() public {
        uint256 depositAmount = 100 * 1e6; // 100 USDC

        // User1 approves coreBanking to spend their mUSDC
        vm.prank(user1);
        mockUSDC.approve(address(coreBanking), depositAmount);

        // User1 deposits into coreBanking
        vm.prank(user1);
        coreBanking.deposit(address(mockUSDC), depositAmount);

        // Assert balances
        assertEq(mockUSDC.balanceOf(user1), (10_000 - 100) * 1e6);
        assertEq(mockUSDC.balanceOf(address(coreBanking)), depositAmount);
        assertEq(coreBanking.getUserBalance(address(mockUSDC), user1), depositAmount);
    }

    function testWithdraw() public {
        uint256 depositAmount = 1000 * 1e6;
        uint256 withdrawAmount = 200 * 1e6;

        // User1 deposits first
        vm.prank(user1);
        mockUSDC.approve(address(coreBanking), depositAmount);
        vm.prank(user1);
        coreBanking.deposit(address(mockUSDC), depositAmount);

        // User1 withdraws
        vm.prank(user1);
        coreBanking.withdraw(address(mockUSDC), withdrawAmount);

        // Assert balances
        assertEq(mockUSDC.balanceOf(user1), (10_000 - depositAmount + withdrawAmount) * 1e6);
        assertEq(mockUSDC.balanceOf(address(coreBanking)), depositAmount - withdrawAmount);
        assertEq(coreBanking.getUserBalance(address(mockUSDC), user1), depositAmount - withdrawAmount);
    }

    function testDepositIntoAave() public {
        // This test requires a mock AaveIntegration contract to be set up.
        // For a full integration test, you would deploy a mock AaveIntegration.
        // For now, we'll assume it's set and test the interaction from CoreBanking.

        // Mock AaveIntegration contract
        address mockAaveIntegration = vm.addr(4);
        coreBanking.setAaveIntegrationContract(mockAaveIntegration);

        uint256 depositAmount = 500 * 1e6; // 500 USDC

        // User1 deposits into coreBanking first
        vm.prank(user1);
        mockUSDC.approve(address(coreBanking), depositAmount);
        vm.prank(user1);
        coreBanking.deposit(address(mockUSDC), depositAmount);

        // Expect transfer from coreBanking to mockAaveIntegration
        vm.expectCall(
            address(mockUSDC),
            abi.encodeWithSelector(IERC20.transfer.selector, mockAaveIntegration, depositAmount)
        );

        // Expect call to AaveIntegration's supplyAsset
        vm.expectCall(
            mockAaveIntegration,
            abi.encodeWithSelector(IAaveIntegration.supplyAsset.selector, address(mockUSDC), depositAmount)
        );

        // User1 deposits into Aave via coreBanking
        vm.prank(user1);
        coreBanking.depositIntoAave(address(mockUSDC), depositAmount);

        // Assert balance in coreBanking for user1 is reduced
        assertEq(coreBanking.getUserBalance(address(mockUSDC), user1), 0);
        // Balance in coreBanking contract should also be reduced by the amount sent to Aave
        // This is a complex check, as the `transfer` from `coreBanking` to `aaveIntegration`
        // moves the tokens from coreBanking's direct balance.
        // You'd typically rely on `vm.expectCall` for external interactions.
    }

    function testWithdrawFromAave() public {
        // This test requires a mock AaveIntegration contract to be set up.
        // Assume tokens are already in Aave for user1.
        address mockAaveIntegration = vm.addr(4);
        coreBanking.setAaveIntegrationContract(mockAaveIntegration);

        uint256 withdrawAmount = 300 * 1e6; // 300 USDC

        // Mock the AaveIntegration contract to transfer tokens back to coreBanking
        // when its withdrawAsset is called by CoreBanking.
        // This is a simplified mock for the test. In reality, you'd mock the aToken balance.
        vm.deal(address(mockAaveIntegration), 0); // Clear mock AaveIntegration's balance
        mockUSDC.mint(mockAaveIntegration, withdrawAmount); // Give it tokens to send back

        // Expect call to AaveIntegration's withdrawAsset
        vm.expectCall(
            mockAaveIntegration,
            abi.encodeWithSelector(IAaveIntegration.withdrawAsset.selector, address(mockUSDC), withdrawAmount, address(coreBanking))
        );

        // Expect transfer from coreBanking to user1 after being received from AaveIntegration
        vm.expectCall(
            address(mockUSDC),
            abi.encodeWithSelector(IERC20.transfer.selector, user1, withdrawAmount)
        );

        // User1 withdraws from Aave via coreBanking.
        vm.prank(user1);
        coreBanking.withdrawFromAave(address(mockUSDC), withdrawAmount);

        // Assert balance in coreBanking for user1 is increased
        assertEq(coreBanking.getUserBalance(address(mockUSDC), user1), withdrawAmount);
        // Assert mockAaveIntegration balance is 0 as it transferred out.
        assertEq(mockUSDC.balanceOf(mockAaveIntegration), 0);
    }
}
