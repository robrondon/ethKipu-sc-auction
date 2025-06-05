// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

contract Auction {
    // Constants
    uint256 public constant COMMISSION_RATE = 2; // 2%
    uint256 public constant MIN_BID_INCREMENT = 5; // 5%
    uint256 public constant TIME_EXTENSION = 10 minutes;

    // State variables
    bool public auctionEnded;
    uint256 public auctionEndTime;
    address public owner;

    // Current winner tracking
    uint256 public highestBid;
    address public highestBidder;

    // Bid tracking
    struct Bid {
        uint256 bidAmount;
        bool refunded;
        uint256 timestamp;
    }

    Bid[] public bids;
    mapping(address user => Bid[] bidsMade) public bidsByUser;
    mapping(address user => uint256 amount) public lastValidBid;

    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    modifier isAuctionActive() {
        // if(block.timestamp >  auctionEndTime && !auctionEnded) {
        //   _endAuction();
        // }
        require(block.timestamp < auctionEndTime, "Auction has ended.");
        require(!auctionEnded, "Auction already ended.");
        _;
    }
}
