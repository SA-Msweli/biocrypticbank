// services/blockchain/aurora/hardhat.config.js
require("@nomicfoundation/hardhat-toolbox");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.20",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  paths: {
    sources: "./contracts",
    artifacts: "./artifacts",
    cache: "./cache",
    tests: "./test",
  },
  networks: {
    aurora_testnet: {
      url: "https://testnet.aurora.dev",
      chainId: 1313161555,
      accounts: process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
    },
  },
  etherscan: {
    apiKey: {
      auroraTestnet: process.env.AURORASCAN_API_KEY || "",
    },
  },
};
