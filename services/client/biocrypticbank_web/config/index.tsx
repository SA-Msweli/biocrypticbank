// config/index.tsx
import { cookieStorage, createStorage, http } from 'wagmi';
import { WagmiAdapter } from '@reown/appkit-adapter-wagmi';
import { arbitrum, aurora, auroraTestnet, avalanche, avalancheFuji, mainnet, near, nearTestnet, sepolia } from 'wagmi/chains';

export const projectId = process.env.NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID || 'YOUR_WALLETCONNECT_PROJECT_ID';

if (!projectId) {
  throw new Error('Project ID is not defined');
}

export const networks = [avalanche, avalancheFuji, mainnet, sepolia, near, nearTestnet, aurora, auroraTestnet, arbitrum];

export const wagmiAdapter = new WagmiAdapter({
  storage: createStorage({
    storage: cookieStorage
  }),
  ssr: true,
  projectId,
  networks,
  transports: {
    [avalanche.id]: http(process.env.NEXT_PUBLIC_AVALANCHE_RPC_URL || 'YOUR_AVALANCHE_RPC_URL_HERE'), // TODO: Add Avalanche RPC URL to .env.local
    [avalancheFuji.id]: http(process.env.NEXT_PUBLIC_AVALANCHE_FUJI_RPC_URL || 'https://api.avax-test.network/ext/bc/C/rpc'),
    [mainnet.id]: http(process.env.NEXT_PUBLIC_MAINNET_RPC_URL || 'YOUR_MAINNET_RPC_URL_HERE'), // TODO: Add Mainnet RPC URL to .env.local
    [sepolia.id]: http(process.env.NEXT_PUBLIC_SEPOLIA_RPC_URL || 'https://eth-sepolia.g.alchemy.com/v2/YOUR_ALCHEMY_KEY'),
    [near.id]: http(process.env.NEXT_PUBLIC_NEAR_RPC_URL || 'YOUR_NEAR_RPC_URL_HERE'), // TODO: Add NEAR RPC URL to .env.local
    [nearTestnet.id]: http(process.env.NEXT_PUBLIC_NEAR_TESTNET_RPC_URL || 'YOUR_NEAR_TESTNET_RPC_URL_HERE'), // TODO: Add NEAR Testnet RPC URL to .env.local
    [aurora.id]: http(process.env.NEXT_PUBLIC_AURORA_RPC_URL || 'YOUR_AURORA_RPC_URL_HERE'), // TODO: Add Aurora RPC URL to .env.local
    [auroraTestnet.id]: http(process.env.NEXT_PUBLIC_AURORA_TESTNET_RPC_URL || 'YOUR_AURORA_TESTNET_RPC_URL_HERE'), // TODO: Add Aurora Testnet RPC URL to .env.local
    [arbitrum.id]: http(process.env.NEXT_PUBLIC_ARBITRUM_RPC_URL || 'YOUR_ARBITRUM_RPC_URL_HERE') // TODO: Add Arbitrum RPC URL to .env.local
  },
});

export const config = wagmiAdapter.wagmiConfig;

// TODO: Replace with your actual deployed contract addresses and ABIs
export const CONTRACT_ADDRESSES = {
  avalancheFuji: {
    cctToken: '0xTODO_CCT_FUJI_ADDRESS', // BioCrypticBankCrossChainToken address on Fuji
    ccipSender: '0xTODO_CCIP_SENDER_FUJI_ADDRESS', // BioCrypticBankCCIPSender address on Fuji
    linkToken: '0x0000000000000000000000000000000000000000', // TODO: Replace with actual LINK token address on Fuji if using LINK as fee token
  },
  sepolia: {
    cctToken: '0xTODO_CCT_SEPOLIA_ADDRESS', // BioCrypticBankCrossChainToken address on Sepolia
    ccipReceiver: '0xTODO_CCIP_RECEIVER_SEPOLIA_ADDRESS', // BioCrypticBankCCIPReceiver address on Sepolia
    linkToken: '0x0000000000000000000000000000000000000000', // TODO: Replace with actual LINK token address on Sepolia if using LINK as fee token
  },
};

export const CCT_ABI = [
  "function approve(address spender, uint256 amount) returns (bool)",
  "function balanceOf(address account) view returns (uint256)",
];

export const CCIP_SENDER_ABI = [
  "function transferTokensCrossChain(uint64 _destinationChainSelector, address _receiver, uint256 _amount, address _feeToken) payable"
];
