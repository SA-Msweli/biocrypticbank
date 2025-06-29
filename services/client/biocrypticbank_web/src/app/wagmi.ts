// src/app/wagmi.ts
import { createConfig, http } from 'wagmi';
import { avalancheFuji, sepolia } from 'wagmi/chains';
import { injected, walletConnect, safe } from 'wagmi/connectors';

// Your WalletConnect Cloud Project ID
// Get one at https://cloud.walletconnect.com/
export const walletConnectProjectId = process.env.NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID || 'YOUR_WALLETCONNECT_PROJECT_ID';

// Configure wagmi.
// This sets up the networks your DApp will support and the connectors available.
export const wagmiConfig = createConfig({
  chains: [avalancheFuji, sepolia], // Specify the chains your DApp will interact with
  connectors: [
    injected(), // Allows connecting via browser extensions like MetaMask
    walletConnect({ projectId: walletConnectProjectId, showQrModal: false }), // WalletConnect for mobile wallets
    safe(), // Gnosis Safe support
  ],
  transports: {
    // Define RPC endpoints for each chain.
    // It's recommended to use environment variables for RPC URLs.
    [avalancheFuji.id]: http(process.env.NEXT_PUBLIC_AVALANCHE_FUJI_RPC_URL || 'https://api.avax-test.network/ext/bc/C/rpc'),
    [sepolia.id]: http(process.env.NEXT_PUBLIC_SEPOLIA_RPC_URL || 'https://eth-sepolia.g.alchemy.com/v2/YOUR_ALCHEMY_KEY'),
  },
});
