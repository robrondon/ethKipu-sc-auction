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
