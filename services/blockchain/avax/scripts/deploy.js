// services/blockchain/avax/scripts/deploy.js

const { ethers } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("Deploying contracts with the account:", deployer.address);

  // --- 1. Deploy RWAHub.sol ---
  console.log("\nDeploying RWAHub...");
  // Pass a unique name and symbol for your RWA tokens
  const RWAHub = await ethers.getContractFactory("RWAHub");
  const rwaHub = await RWAHub.deploy("BioCrypticBankRWA", "BCBRWA");
  await rwaHub.waitForDeployment();
  const rwaHubAddress = await rwaHub.getAddress();
  console.log("RWAHub deployed to:", rwaHubAddress);

  // --- 2. Deploy AaveIntegration.sol ---
  console.log("\nDeploying AaveIntegration...");
  // You need the actual Aave V3 PoolAddressesProvider address for Avalanche (e.g., Fuji Testnet or Mainnet)
  // For Fuji Testnet: "0xF6B5808e018693895e6D83F729E9bA85c678a9c3" (example, verify latest from Aave docs)
  // Check Aave's official documentation for the latest deployed addresses.
  const AAVE_POOL_ADDRESS = "0x87870BcPqVaZjzCe87870BcPqVaZjzCe87870BcPqVaZjzCe"; // Placeholder: REPLACE WITH ACTUAL AAVE V3 POOL ADDRESS FOR AVALANCHE

  const AaveIntegration = await ethers.getContractFactory("AaveIntegration");
  const aaveIntegration = await AaveIntegration.deploy(AAVE_POOL_ADDRESS);
  await aaveIntegration.waitForDeployment();
  const aaveIntegrationAddress = await aaveIntegration.getAddress();
  console.log("AaveIntegration deployed to:", aaveIntegrationAddress);

  // --- 3. Deploy AvalancheCoreBanking.sol ---
  console.log("\nDeploying AvalancheCoreBanking...");
  const AvalancheCoreBanking = await ethers.getContractFactory("AvalancheCoreBanking");
  const avalancheCoreBanking = await AvalancheCoreBanking.deploy();
  await avalancheCoreBanking.waitForDeployment();
  const avalancheCoreBankingAddress = await avalancheCoreBanking.getAddress();
  console.log("AvalancheCoreBanking deployed to:", avalancheCoreBankingAddress);

  // --- 4. Link Contracts in AvalancheCoreBanking ---
  console.log("\nLinking contracts in AvalancheCoreBanking...");

  // Set AaveIntegration contract address in AvalancheCoreBanking
  await avalancheCoreBanking.setAaveIntegrationContract(aaveIntegrationAddress);
  console.log("AaveIntegration contract set in AvalancheCoreBanking.");

  // Set RWAHub contract address in AvalancheCoreBanking
  await avalancheCoreBanking.setRWAHubContract(rwaHubAddress);
  console.log("RWAHub contract set in AvalancheCoreBanking.");

  console.log("\nAll Avalanche contracts deployed and linked successfully!");

  // --- Optional: Verify contracts on Snowtrace ---
  // You would typically uncomment and run these in a separate step or after successful deployment.
  // Make sure SNOWTRACE_API_KEY is set in your .env
  console.log("\nVerifying contracts (this might take a while)...");
  try {
    await hre.run("verify:verify", {
      address: rwaHubAddress,
      constructorArguments: ["BioCrypticBankRWA", "BCBRWA"],
    });
    console.log("RWAHub verified successfully.");
  } catch (error) {
    console.error("RWAHub verification failed:", error.message);
  }

  try {
    await hre.run("verify:verify", {
      address: aaveIntegrationAddress,
      constructorArguments: [AAVE_POOL_ADDRESS],
    });
    console.log("AaveIntegration verified successfully.");
  } catch (error) {
    console.error("AaveIntegration verification failed:", error.message);
  }

  try {
    await hre.run("verify:verify", {
      address: avalancheCoreBankingAddress,
      constructorArguments: [],
    });
    console.log("AvalancheCoreBanking verified successfully.");
  } catch (error) {
    console.error("AvalancheCoreBanking verification failed:", error.message);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
