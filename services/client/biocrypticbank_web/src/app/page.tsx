// src/app/page.tsx
'use client';

import Image from 'next/image';
import styles from './page.module.css';
import { appKitModal } from '../../context';
import { useAccount, useChainId, useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { networks, CONTRACT_ADDRESSES, CCT_ABI, CCIP_SENDER_ABI } from '../../config';
import React, { useState, useEffect, useRef } from 'react'; // Added useRef
import { parseEther, isAddress } from 'ethers';
import QRCodeGenerator from 'qrcode'; // Corrected import for the core 'qrcode' library

export default function Home() {
  const { open } = appKitModal;
  const { address, isConnected } = useAccount();
  const chainId = useChainId();

  const chain = networks.find(c => c.id === chainId);

  // State for generating QR code
  const [qrAmount, setQrAmount] = useState('');
  const [qrChainId, setQrChainId] = useState<number | undefined>(chainId);
  const [qrCodeData, setQrCodeData] = useState('');
  const qrCanvasRef = useRef<HTMLCanvasElement>(null); // Ref for the QR code canvas

  // State for sending payments (scanning QR)
  const [scannedQrData, setScannedQrData] = useState('');
  const [sendRecipientAddress, setSendRecipientAddress] = useState('');
  const [sendAmount, setSendAmount] = useState('');
  const [sendDestinationChainId, setSendDestinationChainId] = useState<number | undefined>();
  const [sendCCTAddress, setSendCCTAddress] = useState('');


  // Wagmi hooks for contract interaction
  const { writeContract: approveWrite, data: approveHash } = useWriteContract();
  const { isLoading: isApproving, isSuccess: isApproved } = useWaitForTransactionReceipt({ hash: approveHash });

  const { writeContract: transferWrite, data: transferHash } = useWriteContract();
  const { isLoading: isTransferring, isSuccess: isTransferred } = useWaitForTransactionReceipt({ hash: transferHash });

  // Update QR code data string whenever address, chain, or amount changes
  useEffect(() => {
    if (address && qrChainId) {
      const data = {
        recipient: address,
        chainId: qrChainId,
        amount: qrAmount,
        cctAddress: CONTRACT_ADDRESSES[chain?.name.toLowerCase().includes('avalanche') ? 'avalancheFuji' : 'sepolia']?.cctToken || '0xTODO_CCT_ADDRESS_ON_QR_CHAIN' // Default to a placeholder if not found
      };
      setQrCodeData(JSON.stringify(data));
    } else {
      setQrCodeData('');
    }
  }, [address, qrAmount, qrChainId, chain?.name]);

  // Effect to draw QR code on canvas when qrCodeData changes
  useEffect(() => {
    if (qrCodeData && qrCanvasRef.current) {
      QRCodeGenerator.toCanvas(qrCanvasRef.current, qrCodeData, { width: 256, errorCorrectionLevel: 'H' }, function (error) {
        if (error) console.error(error);
      });
    }
  }, [qrCodeData]);

  // Handle QR code scanning (parsing the JSON string)
  const handleScanQr = () => {
    try {
      const parsedData = JSON.parse(scannedQrData);
      if (parsedData.recipient && isAddress(parsedData.recipient) && parsedData.chainId) {
        setSendRecipientAddress(parsedData.recipient);
        setSendDestinationChainId(Number(parsedData.chainId));
        setSendAmount(parsedData.amount || ''); // Amount is optional in QR
        setSendCCTAddress(parsedData.cctAddress || ''); // CCT address from QR
      } else {
        alert('Invalid QR code data format.');
      }
    } catch (e) {
      alert('Failed to parse QR code data. Make sure it is valid JSON.');
      console.error(e);
    }
  };

  // Handle cross-chain transfer initiation
  const handleTransfer = async () => {
    if (!isConnected || !address || !chain || !sendRecipientAddress || !sendDestinationChainId || !sendAmount || !sendCCTAddress) {
      alert('Please connect wallet, enter all transfer details, and scan a valid QR code.');
      return;
    }

    if (!isAddress(sendRecipientAddress)) {
      alert('Invalid recipient address.');
      return;
    }

    // Determine current chain's CCIP Sender address and LINK token for fees
    const currentChainConfig = CONTRACT_ADDRESSES[chain.name.toLowerCase().includes('avalanche') ? 'avalancheFuji' : 'sepolia'];

    if (!currentChainConfig || !currentChainConfig.ccipSender || !currentChainConfig.cctToken || !currentChainConfig.linkToken) {
      alert('Contract addresses for current chain are not configured. Please update CONTRACT_ADDRESSES.');
      return;
    }

    const amountInWei = parseEther(sendAmount); // Convert amount to wei (assuming 18 decimals)

    // Step 1: Approve the CCIP Sender contract to spend CCT tokens
    try {
      console.log(`Approving ${currentChainConfig.ccipSender} to spend ${sendAmount} CCT from ${currentChainConfig.cctToken}`);
      approveWrite({
        address: currentChainConfig.cctToken as `0x${string}`,
        abi: CCT_ABI,
        functionName: 'approve',
        args: [currentChainConfig.ccipSender as `0x${string}`, amountInWei],
      });
    } catch (error) {
      console.error("Approval failed:", error);
      alert(`Approval failed: ${error.message}`);
    }
  };

  // Monitor approval status and proceed to transfer
  useEffect(() => {
    if (isApproved) {
      console.log('Approval successful. Proceeding with cross-chain transfer.');
      const currentChainConfig = CONTRACT_ADDRESSES[chain?.name.toLowerCase().includes('avalanche') ? 'avalancheFuji' : 'sepolia'];

      // Step 2: Perform the cross-chain transfer
      transferWrite({
        address: currentChainConfig.ccipSender as `0x${string}`,
        abi: CCIP_SENDER_ABI,
        functionName: 'transferTokensCrossChain',
        args: [
          BigInt(sendDestinationChainId!), // Destination Chain Selector
          sendRecipientAddress as `0x${string}`, // End user recipient
          parseEther(sendAmount), // Amount to transfer
          currentChainConfig.linkToken as `0x${string}`, // Fee token (LINK)
        ],
        value: parseEther('0.01'), // TODO: This should be dynamically calculated from router.getFee if paying in native token
                                    // For now, a placeholder native token value for testing
      });
    }
  }, [isApproved, transferWrite, sendRecipientAddress, sendDestinationChainId, sendAmount, chain]);

  useEffect(() => {
    if (isTransferred) {
      alert('Cross-chain transfer initiated successfully!');
      // TODO: Add transaction tracking link (e.g., CCIP Explorer)
    }
  }, [isTransferred]);


  return (
    <main className={styles.main}>
      <div className={styles.description}>
        <p>
          BioCrypticBank Cross-Chain MVP
        </p>
        <div>
          <a
            href="https://chain.link/ccip"
            target="_blank"
            rel="noopener noreferrer"
          >
            Powered by Chainlink CCIP
          </a>
        </div>
      </div>

      <div className={styles.center}>
        <Image
          className={styles.logo}
          src="/next.svg" // TODO: Replace with BioCrypticBank logo
          alt="Next.js Logo"
          width={180}
          height={37}
          priority
        />
      </div>

      <div className={styles.grid}>
        {isConnected ? (
          <>
            <div>
              <p>Connected to: {address}</p>
              <p>Chain: {chain?.name} (ID: {chain?.id})</p>
              <button onClick={() => open()} className={styles.card}>
                Manage Wallet
              </button>
            </div>

            {/* Section for Receiving Payments (Generate QR Code) */}
            <div className={styles.card}>
              <h2>Receive CCT Payments</h2>
              {address && chain && (
                <>
                  <p>Your Current Address: {address}</p>
                  <p>Current Chain: {chain.name}</p>
                  <label>
                    Amount (optional):
                    <input
                      type="number"
                      value={qrAmount}
                      onChange={(e) => setQrAmount(e.target.value)}
                      placeholder="e.g., 100"
                      className={styles.inputField}
                    />
                  </label>
                  <br />
                  <label>
                    Receive on Chain:
                    <select
                        value={qrChainId}
                        onChange={(e) => setQrChainId(Number(e.target.value))}
                        className={styles.selectField}
                    >
                        {networks.map(net => (
                            <option key={net.id} value={net.id}>
                                {net.name}
                            </option>
                        ))}
                    </select>
                  </label>
                  <br />
                  {qrCodeData && (
                    <div style={{ margin: '10px 0' }}>
                      {/* Replaced QRCode component with a canvas */}
                      <canvas ref={qrCanvasRef} id="qrCanvas"></canvas>
                      <p style={{ wordBreak: 'break-all', fontSize: '0.8em' }}>
                        QR Data: {qrCodeData}
                      </p>
                    </div>
                  )}
                </>
              )}
            </div>

            {/* Section for Sending Payments (Scan QR Code) */}
            <div className={styles.card}>
              <h2>Send CCT Payments</h2>
              <label>
                Paste QR Code Data:
                <input
                  type="text"
                  value={scannedQrData}
                  onChange={(e) => setScannedQrData(e.target.value)}
                  placeholder="Paste JSON QR data here"
                  className={styles.inputField}
                />
              </label>
              <button onClick={handleScanQr} className={styles.button}>
                Parse QR Data
              </button>

              {sendRecipientAddress && sendDestinationChainId && sendAmount && (
                <div style={{ marginTop: '20px' }}>
                  <h3>Transaction Details from QR:</h3>
                  <p>Recipient: {sendRecipientAddress}</p>
                  <p>Amount: {sendAmount} CCT</p>
                  <p>Destination Chain: {networks.find(n => n.id === sendDestinationChainId)?.name || sendDestinationChainId}</p>
                  <p>CCT Address on Dest Chain (from QR): {sendCCTAddress}</p>
                  <button
                    onClick={handleTransfer}
                    className={styles.button}
                    disabled={isApproving || isTransferring}
                  >
                    {isApproving ? 'Approving CCT...' : isTransferring ? 'Transferring...' : 'Send CCT Cross-Chain'}
                  </button>
                  {(isApproving || isTransferring) && <p>Please confirm transaction in your wallet.</p>}
                  {approveHash && <p>Approval TX Hash: {approveHash}</p>}
                  {transferHash && <p>Transfer TX Hash: {transferHash}</p>}
                </div>
              )}
            </div>
          </>
        ) : (
          <button onClick={() => open()} className={styles.card}>
            Connect Wallet
          </button>
        )}
      </div>
    </main>
  );
}
