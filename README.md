BioCrypticBank
Project Name: (To Be Decided)
Overview
BioCrypticBank is a cutting-edge decentralized financial platform designed to bridge the gap between traditional banking services and the rapidly evolving world of blockchain. Leveraging the power of multiple blockchain networks, including NEAR Protocol, Aurora EVM, and Avalanche, BioCrypticBank aims to provide secure, transparent, and efficient financial services, including digital identity management, multi-option account recovery, core banking functionalities, and seamless integration with decentralized finance (DeFi) and Real-World Asset (RWA) ecosystems.

This project is structured to ensure scalability, robust security, and a user-friendly experience across both mobile and web platforms.

Key Features
Decentralized Identity (DID) Management (NEAR Native): Secure and user-controlled digital identities on the NEAR Protocol.

Multi-Option Account Recovery (NEAR Native): Robust mechanisms for account recovery through trusted guardians on NEAR.

Core Banking Operations (NEAR & EVM):

Native NEAR token deposits and withdrawals on the NEAR Protocol.

EVM-compatible token (ERC-20) deposits and withdrawals on Aurora and Avalanche.

DeFi Integrations: Seamless interaction with leading DeFi protocols like Aave on Aurora and Avalanche for lending and borrowing.

Real-World Asset (RWA) Tokenization: Infrastructure for tokenizing and managing real-world assets on Aurora and Avalanche.

Cross-Chain Interoperability: Facilitation of value transfer and interaction across NEAR, Aurora, and Avalanche.

Fiat-to-Crypto On/Off-Ramps: Integration with traditional banking APIs and payment gateways for easy entry and exit points.

Biometric Authentication: Enhanced security features for user authentication.

Comprehensive Backend Services: Robust off-chain services to manage user accounts, transactions, and integrations.

Architecture Overview
BioCrypticBank employs a multi-layered architecture to ensure a modular, scalable, and resilient system:

Client Layer: Mobile (Flutter) and Web (Next.js/React) applications providing user interfaces.

Off-Chain Services Layer: A .NET Core backend API handling business logic, user management, and integrations with external services. This layer also includes dedicated microservices for biometrics, payment gateways, traditional banking APIs, and DEX/liquidity providers.

Blockchain Layer: Smart contracts deployed on:

NEAR Protocol: For core native functionalities like DID and account recovery (Rust).

Aurora EVM: For EVM-compatible core banking, DeFi integrations (Aave), and initial RWA functionalities (Solidity).

Avalanche (C-Chain & Subnets): For EVM-compatible core banking, DeFi integrations (Aave), and more complex RWA logic (Solidity).

Integration Services: Dedicated modules or microservices for connecting with external fiat payment providers, traditional banks, and decentralized exchanges.

Oracle Networks: Leveraging Chainlink Decentralized Oracle Networks (DONs) for reliable off-chain data (e.g., price feeds) for smart contract operations.

Refer to docs/architecture/system_design_spec.md and the PlantUML diagrams in docs/architecture/diagrams/ for a detailed visual representation.

Technology Stack
Frontend: Flutter (Mobile), Next.js / React (Web)

Backend: .NET Core

Databases: PostgreSQL / MongoDB (Off-chain)

Blockchain Platforms:

NEAR Protocol: Rust (for native contracts), JavaScript SDK (for client interaction)

Aurora EVM: Solidity (for EVM-compatible contracts), Hardhat / Foundry (development tools)

Avalanche: Solidity (for EVM-compatible contracts), Hardhat / Foundry (development tools)

Oracles: Chainlink

Containerization: Docker

Version Control: Git

Setup and Installation
To set up the BioCrypticBank project for development, follow these high-level steps. More detailed instructions can be found in the docs/ directory.

Clone the Repository:

git clone https://github.com/your-org/BioCrypticBank.git
cd BioCrypticBank

Environment Variables:
Create .env files based on .env.example in each service directory (services/client/bcb_mobile, services/client/bcb-web, services/backend, services/integrations/*) and fill in the required configurations (API keys, RPC URLs, etc.).

Install Dependencies:

Node.js & npm/yarn: For web client and Solidity contract development tools (Hardhat/Foundry).

Flutter SDK: For mobile app development.

.NET SDK: For backend services.

Rust Toolchain & wasm32-unknown-unknown target: For NEAR native contract development.

Run npm install or yarn install in services/client/bcb-web and npx hardhat compile or forge build in services/blockchain/aurora and services/blockchain/avax.

Database Setup:
Refer to scripts/db_migrations/init_db.sql and relevant backend documentation to set up your database.

Building Smart Contracts
Smart contracts are located in services/blockchain/. Each sub-directory contains its own build.sh script.

NEAR Rust Contracts:

cd services/blockchain/near-rs
chmod +x build.sh
./build.sh

Aurora & Avalanche Solidity Contracts:

cd services/blockchain/aurora # or services/blockchain/avax
chmod +x build.sh
./build.sh

Running the Project
Refer to the scripts/ directory for convenience scripts.

Start Development Servers:

./scripts/start_dev_servers.sh

This script would typically start the backend, client apps, and any necessary local blockchain nodes (e.g., Hardhat local network, Near sandbox).

Testing
Each service and smart contract has its own testing suite.

Smart Contracts:

NEAR Rust: cd services/blockchain/near-rs && cargo test --workspace

Aurora/Avalanche Solidity: cd services/blockchain/aurora && npx hardhat test or forge test

Backend: Refer to the services/backend/Tests directory for details.

Client: Refer to services/client/bcb_mobile/test and services/client/bcb-web/test.

Contribution
Contributions are welcome! Please refer to our CONTRIBUTING.md (TBD) for guidelines on how to contribute to the project.

License
(To Be Decided - e.g., MIT, Apache 2.0)