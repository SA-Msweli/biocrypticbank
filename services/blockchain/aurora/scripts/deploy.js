// services/blockchain/aurora/scripts/deploy.js

const { ethers } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("Deploying contracts with the account:", deployer.address);

  // --- 1. Deploy AaveIntegration.sol for Aurora ---
  console.log("\nDeploying AaveIntegration for Aurora...");
  // You need the actual Aave V3 PoolAddressesProvider address for Aurora (e.g., Testnet or Mainnet)
  // Check Aave's official documentation for the latest deployed addresses.
  const AAVE_POOL_ADDRESS_AURORA = "0x87870BcPqVaZjzCe87870BcPqVaZjzCe87870BcPqVaZjzCe"; // Placeholder: REPLACE WITH ACTUAL AAVE V3 POOL ADDRESS FOR AURORA

  const AaveIntegrationAurora = await ethers.getContractFactory("AaveIntegration");
  const aaveIntegrationAurora = await AaveIntegrationAurora.deploy(AAVE_POOL_ADDRESS_AURORA);
  await aaveIntegrationAurora.waitForDeployment();
  const aaveIntegrationAuroraAddress = await aaveIntegrationAurora.getAddress();
  console.log("AaveIntegration (Aurora) deployed to:", aaveIntegrationAuroraAddress);

  // --- 2. Deploy RWAProxy.sol for Aurora ---
  console.log("\nDeploying RWAProxy for Aurora...");
  // This RWAProxy will point to the RWAHub contract deployed on Avalanche.
  // You NEED the actual address of your deployed Avalanche RWAHub contract here.
  const AVALANCHE_RWA_HUB_ADDRESS = "0xYourDeployedAvalancheRWAHubAddress"; // Placeholder: REPLACE WITH ACTUAL DEPLOYED AVALANCHE RWAHUB ADDRESS

  const RWAProxy = await ethers.getContractFactory("RWAProxy");
  const rwaProxy = await RWAProxy.deploy(AVALANCHE_RWA_HUB_ADDRESS);
  await rwaProxy.waitForDeployment();
  const rwaProxyAddress = await rwaProxy.getAddress();
  console.log("RWAProxy (Aurora) deployed to:", rwaProxyAddress);

  // --- 3. Deploy BioCrypticEvmCoreBanking.sol for Aurora ---
  console.log("\nDeploying BioCrypticEvmCoreBanking for Aurora...");
  // The constructor for BioCrypticEvmCoreBanking expects initialOwner, _aavePool, _aaveTreasury, _router, _uniswapV3SwapRouter
  // _aavePool will be the Aurora AaveIntegration contract itself (or the actual Aave Pool directly if you choose).
  // _aaveTreasury can be the deployer's address or a dedicated treasury address.
  // _router is the Chainlink CCIP Router address for Aurora.
  // _uniswapV3SwapRouter is the Uniswap V3 Swap Router address for Aurora.
  const AAVE_TREASURY_ADDRESS_AURORA = deployer.address; // Or a specific treasury address
  const CHAINLINK_CCIP_ROUTER_AURORA = "0xYourChainlinkCCIPRouterAddressForAurora"; // Placeholder: REPLACE WITH ACTUAL CHAINLINK CCIP ROUTER ADDRESS FOR AURORA
  const UNISWAP_V3_SWAP_ROUTER_AURORA = "0xYourUniswapV3SwapRouterAddressForAurora"; // Placeholder: REPLACE WITH ACTUAL UNISWAP V3 SWAP ROUTER ADDRESS FOR AURORA

  const BioCrypticEvmCoreBanking = await ethers.getContractFactory("BioCrypticEvmCoreBanking");
  const bioCrypticEvmCoreBanking = await BioCrypticEvmCoreBanking.deploy(
    deployer.address, // initialOwner
    aaveIntegrationAuroraAddress, // _aavePool (Aurora's AaveIntegration)
    AAVE_TREASURY_ADDRESS_AURORA, // _aaveTreasury
    CHAINLINK_CCIP_ROUTER_AURORA, // _router
    UNISWAP_V3_SWAP_ROUTER_AURORA // _uniswapV3SwapRouter
  );
  await bioCrypticEvmCoreBanking.waitForDeployment();
  const bioCrypticEvmCoreBankingAddress = await bioCrypticEvmCoreBanking.getAddress();
  console.log("BioCrypticEvmCoreBanking (Aurora) deployed to:", bioCrypticEvmCoreBankingAddress);

  console.log("\nAll Aurora contracts deployed successfully!");

  // --- Optional: Verify contracts on AuroraScan ---
  console.log("\nVerifying contracts (this might take a while)...");
  try {
    await hre.run("verify:verify", {
      address: aaveIntegrationAuroraAddress,
      constructorArguments: [AAVE_POOL_ADDRESS_AURORA],
    });
    console.log("AaveIntegration (Aurora) verified successfully.");
  } catch (error) {
    console.error("AaveIntegration (Aurora) verification failed:", error.message);
  }

  try {
    await hre.run("verify:verify", {
      address: rwaProxyAddress,
      constructorArguments: [AVALANCHE_RWA_HUB_ADDRESS],
    });
    console.log("RWAProxy (Aurora) verified successfully.");
  } catch (error) {
    console.error("RWAProxy (Aurora) verification failed:", error.message);
  }

  try {
    await hre.run("verify:verify", {
      address: bioCrypticEvmCoreBankingAddress,
      constructorArguments: [
        deployer.address,
        aaveIntegrationAuroraAddress,
        AAVE_TREASURY_ADDRESS_AURORA,
        CHAINLINK_CCIP_ROUTER_AURORA,
        UNISWAP_V3_SWAP_ROUTER_AURORA
      ],
    });
    console.log("BioCrypticEvmCoreBanking (Aurora) verified successfully.");
  } catch (error) {
    console.error("BioCrypticEvmCoreBanking (Aurora) verification failed:", error.message);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
