// blockchain/ccip/scripts/deployCrossChainToken.js
const hre = require("hardhat");

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  console.log("Deploying BioCrypticBankCrossChainToken with the account:", deployer.address);

  const tokenName = "BioCrypticBank Cross-Chain Token";
  const tokenSymbol = "BCC";

  // Deploy BioCrypticBankCrossChainToken
  const BioCrypticBankCrossChainToken = await hre.ethers.getContractFactory("BioCrypticBankCrossChainToken");
  const cct = await BioCrypticBankCrossChainToken.deploy(deployer.address, tokenName, tokenSymbol);

  await cct.waitForDeployment();

  console.log(`BioCrypticBankCrossChainToken deployed to: ${cct.target} on network ${hre.network.name}`);

  // TODO: Add verification logic here if it's not already in your hardhat.config.ts
  // For manual verification after deployment (adjust arguments for your constructor):
  // npx hardhat verify --network fuji <cct_fuji_address> "deployer_address" "token_name" "token_symbol"
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});