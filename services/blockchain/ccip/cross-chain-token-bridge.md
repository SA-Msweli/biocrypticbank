# 🔗 Cross-Chain Token Bridge Setup Guide (Chainlink CCIP)

This guide walks you through deploying a burn-and-mint token bridge using Chainlink CCIP, including:

- ✅ `CrossChainToken (CCT)`
- ✅ `CCIPSender` (on source chain)
- ✅ `CCIPReceiver` (on destination chain)

---

## 📦 Requirements

### ✅ Tools
- Node.js (v16+)
- Hardhat or Foundry
- Solidity 0.8.19 compatible environment
- Web3 wallet (e.g., MetaMask)
- Access to testnets (e.g., Avalanche Fuji, Ethereum Sepolia)
- Faucet access for testnet AVAX / ETH / LINK

### ✅ Addresses Per Chain
You need these per network:

| Parameter         | Description                         | Where to Find                           |
|------------------|-------------------------------------|------------------------------------------|
| CCIP Router       | Chainlink CCIP Router address        | [Chainlink Docs](https://docs.chain.link/ccip/supported-networks) |
| LINK Token        | LINK token contract address          | Same as above                            |
| Chain Selector    | Chain-specific identifier for CCIP   | Same as above                            |

---

## 📁 Overview of Components

| Contract        | Chain          | Responsibility                                |
|----------------|----------------|-----------------------------------------------|
| `CrossChainToken` | Both chains   | ERC20 with mint/burn controlled by roles      |
| `CCIPSender`     | Source chain   | Burns tokens and sends message via CCIP       |
| `CCIPReceiver`   | Destination    | Verifies source and mints tokens upon receipt |

---

## 🚀 Deployment Steps

### 1️⃣ Deploy `CrossChainToken` on Both Chains

```solidity
new CrossChainToken("CrossChainToken", "CCT")
```

Do this on both source and destination chains. No initial supply is needed.

---

### 2️⃣ Deploy `CCIPSender` on Source Chain

```solidity
new CCIPSender(
  _router,     // Chainlink CCIP Router on source chain
  _link,       // LINK token on source chain
  _cct         // CCT token address on source chain
)
```

---

### 3️⃣ Deploy `CCIPReceiver` on Destination Chain

```solidity
new CCIPReceiver(
  _router,     // Chainlink CCIP Router on destination chain
  _cct         // CCT token address on destination chain
)
```

---

## 🔧 Post-Deployment Configuration

### 🔐 Grant Roles on `CrossChainToken`

#### On Source Chain

```solidity
cct.grantBurnerRole(address(ccipSender))
```

#### On Destination Chain

```solidity
cct.grantMinterRole(address(ccipReceiver))
```

---

### 🔒 Authorize Sender on `CCIPReceiver`

```solidity
ccipReceiver.setAuthorizedSender(
  sourceChainSelector,     // e.g., 14767482510784806043 for Fuji
  address(ccipSender),
  true
)
```

Use the correct selector from the Chainlink docs.

---

## 🧪 Testing Checklist

| Test                          | Expected Result                                     |
|------------------------------|-----------------------------------------------------|
| Call `transferTokensCrossChain()` | Emits `TokensTransferred`                        |
| CCIP message routed           | `TokensReceived` emitted on destination            |
| Receiver gets CCT tokens      | `mint()` called with correct amount                |
| Fees deducted appropriately   | LINK or native balance decreases as expected       |

Use a faucet to fund test wallets with LINK and native tokens.

---

## 🧼 Admin Utilities

| Function                     | Description                                   |
|-----------------------------|-----------------------------------------------|
| `fundWithLINK()`            | Pre-fund contract with LINK for CCIP fees     |
| `withdrawLINK(address)`     | Withdraw LINK from contract                   |
| `withdrawNative(address)`   | Withdraw native tokens (AVAX, ETH, etc.)      |

---

## 🌍 Example Chain Selectors & Addresses

| Chain           | Selector             | Router Address        | LINK Address         |
|-----------------|----------------------|------------------------|----------------------|
| Avalanche Fuji  | 14767482510784806043 | `0x...` (Chainlink)    | `0x...`              |
| Ethereum Sepolia| 16015286601757825753 | `0x...`                | `0x...`              |

📚 [Chainlink CCIP Supported Networks](https://docs.chain.link/ccip/supported-networks)

---

## ✅ Summary

- Deploy `CCT` on both chains
- Deploy `CCIPSender` on source, `CCIPReceiver` on destination
- Grant appropriate roles (`burner`, `minter`)
- Authorize sender in receiver
- Test `transferTokensCrossChain()`
- Verify mint on receiver side

You now have a minimal yet secure CCIP-powered token bridge using burn-and-mint architecture.

---
