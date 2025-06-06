# Auction Smart Contract

A smart contract that implements an auction system on the Ethereum blockchain. Built as part of a Eth Kipu blockchain development course assignment.

## Overview

This contract allows users to participate in an auction by placing bids. The highest bidder wins the auction, and all other participants receive refunds with a 2% commission deducted.

## Main Features

- **Place Bids**: Users can bid on the auction item
- **Minimum Bid Increment**: Each bid must be at least 5% higher than the previous
- **Time Extension**: Auction extends 10 minutes if a bid is placed in the last 10 minutes
- **Automatic Refunds**: Non-winners get their money back (minus 2% commission)
- **Partial Refunds**: Users can withdraw excess amounts during the auction

## Deployment (Using Remix)

1. **Open Remix IDE**: Go to https://remix.ethereum.org
2. **Create New File**: Name it `Auction.sol`
3. **Copy Contract Code**: Paste the Solidity code
4. **Compile**:
   - Go to "Solidity Compiler" tab
   - Select compiler version 0.8.24
   - Click "Compile Auction.sol"
5. **Deploy**:
   - Go to "Deploy & Run Transactions" tab
   - Select "Injected Provider - MetaMask"
   - Choose Sepolia network in MetaMask
   - Enter duration in minutes (e.g., 1440 for 24 hours)
   - Click "Deploy"
6. **Verify on Etherscan**:
   - Copy contract address
   - Go to Sepolia Etherscan
   - Verify and publish source code

## Contract Information

- **Network**: Sepolia Testnet
- **Solidity Version**: ^0.8.24
- **License**: MIT
- **Commission Rate**: 2%
- **Minimum Bid Increment**: 5%
- **Time Extension**: 10 minutes

## Key Functions

| Function           | Description                    | Who Can Call |
| ------------------ | ------------------------------ | ------------ |
| `bid()`            | Place a bid in the auction     | Anyone       |
| `getWinner()`      | Get current highest bidder     | Anyone       |
| `getAllBids()`     | Get all bids placed            | Anyone       |
| `endAuction()`     | End the auction                | Owner only   |
| `refundUsers()`    | Refund all non-winners         | Owner only   |
| `withdrawRefund()` | Claim your refund              | Participants |
| `partialRefund()`  | Withdraw excess during auction | Participants |

## Important Notes

- **Minimum Bid**: Each bid must be at least 5% higher than the current highest
- **Commission**: 2% fee is deducted from refunds
- **Time Extension**: Auction extends if bids are placed in the last 10 minutes
- **No Direct Transfers**: Must use `bid()` function, direct ETH transfers are rejected

## Rules

1. Auction has a set duration (defined at creation)
2. Only the owner can end the auction
3. Bids must be higher than the current highest bid by at least 5%
4. Winner pays the full bid amount
5. Losers get refunds minus 2% commission
6. Late bids (within 10 minutes of end) extend the auction

## Contact

- **Student**: Robert Rondón
- **Course**: Eth Kipu Ethereum Developer Pack
- **Assignment**: Final Project - Module 2

---

**Deployed Contract**: `0x0A83D6FffdeD4CdE239BDB6A55566A51Fb65181c`  
**Etherscan Link**: `https://sepolia.etherscan.io/address/0x0a83d6fffded4cde239bdb6a55566a51fb65181c`
