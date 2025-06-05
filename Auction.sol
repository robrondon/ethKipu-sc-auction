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
        address bidder;
        uint256 bidAmount;
        bool refunded;
        uint256 timestamp;
    }

    Bid[] public bids;
    mapping(address user => Bid[] bidsMade) public bidsByUser;
    mapping(address user => uint256 totalAmount) public totalDepositedByUser;
    mapping(address user => uint256 amount) public lastValidUserBid;

    // Events
    event NewBid(address indexed bidder, uint amount);

    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner has permission");
        _;
    }

    modifier isAuctionActive() {
        require(block.timestamp < auctionEndTime, "Auction has ended.");
        require(!auctionEnded, "Auction already ended.");
        _;
    }

    constructor(uint256 _durationMinutes) {
        owner = msg.sender;
        auctionEndTime = block.timestamp + (_durationMinutes * 60);
    }

    function withdrawFunds() external onlyOwner {
        require(address(this).balance > 0, "No funds to withdraw");
        payable(owner).transfer(address(this).balance);
    }

    function bid() external payable isAuctionActive {
        require(msg.value > 0, "Bid amount must be greater than zero");
        require(
            msg.value >= highestBid + ((highestBid * MIN_BID_INCREMENT) / 100),
            "Bid must be at least 5% higher than current highest"
        );

        // Updating user bids tracking
        bidsByUser[msg.sender].push(
            Bid({
                bidder: msg.sender,
                bidAmount: msg.value,
                refunded: false,
                timestamp: block.timestamp
            })
        );
        lastValidUserBid[msg.sender] = msg.value;
        totalDepositedByUser[msg.sender] += msg.value;

        // updating total bids
        bids.push(
            Bid({
                bidder: msg.sender,
                bidAmount: msg.value,
                refunded: false,
                timestamp: block.timestamp
            })
        );

        // updating bid winner tracking
        highestBid = msg.value;
        highestBidder = msg.sender;

        if (auctionEndTime - block.timestamp < 10 minutes) {
            auctionEndTime = block.timestamp + TIME_EXTENSION;
        }

        emit NewBid(highestBidder, highestBid);
    }
}
