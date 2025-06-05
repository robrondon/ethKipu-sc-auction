// SPDX-License-Identifier: MIT
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
        uint256 timestamp;
    }

    struct UserBid {
        uint256 bidAmount;
        uint256 timestamp;
    }

    Bid[] public bids;
    address[] public participants;

    mapping(address user => bool participated) public hasParticipated;
    mapping(address user => UserBid[] bidsMade) public bidsByUser;
    mapping(address user => uint256 totalAmount) public totalDepositedByUser;
    mapping(address user => uint256 amount) public lastValidUserBid;

    // Events
    event NewBid(address indexed bidder, uint amount);
    event AuctionEnded(address winner, uint256 amount);
    event RefundIssued(address indexed bidder, uint256 amount);
    event RefundFailed(address indexed bidder, uint256 amount);

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

    modifier isAuctionFinished() {
        require(block.timestamp > auctionEndTime, "Auction is still ongoing.");
        require(auctionEnded, "Auction is not ended.");
        _;
    }

    modifier hasAWinner() {
        require(highestBidder != address(0), "There is no winner");
        _;
    }

    constructor(uint256 _durationMinutes) {
        require(_durationMinutes > 0, "Duration must be positive");
        require(_durationMinutes <= 10080, "Duration too long"); // Max 1 week
        owner = msg.sender;
        auctionEndTime = block.timestamp + (_durationMinutes * 60);
    }

    function withdrawFunds() external onlyOwner isAuctionFinished {
        require(address(this).balance > 0, "No funds to withdraw");

        for (uint256 i = 0; i < participants.length; i++) {
            if (participants[i] != highestBidder) {
                require(
                    totalDepositedByUser[participants[i]] == 0,
                    "Some users still need refund"
                );
            }
        }

        (bool success, ) = payable(owner).call{value: address(this).balance}(
            ""
        );
        require(success, "Withdrawal failed");
    }

    function bid() external payable isAuctionActive {
        require(msg.value > 0, "Bid amount must be greater than zero");
        require(
            msg.value >= highestBid + ((highestBid * MIN_BID_INCREMENT) / 100),
            "Bid must be at least 5% higher than current highest"
        );

        // Updating user bids tracking
        bidsByUser[msg.sender].push(
            UserBid({bidAmount: msg.value, timestamp: block.timestamp})
        );
        lastValidUserBid[msg.sender] = msg.value;
        totalDepositedByUser[msg.sender] += msg.value;

        // updating total bids
        bids.push(
            Bid({
                bidder: msg.sender,
                bidAmount: msg.value,
                timestamp: block.timestamp
            })
        );

        // updating bid winner tracking
        highestBid = msg.value;
        highestBidder = msg.sender;

        if (!hasParticipated[msg.sender]) {
            participants.push(msg.sender);
            hasParticipated[msg.sender] = true;
        }

        if (auctionEndTime - block.timestamp < 10 minutes) {
            auctionEndTime = block.timestamp + TIME_EXTENSION;
        }

        emit NewBid(highestBidder, highestBid);
    }

    function endAuction() external onlyOwner {
        require(
            block.timestamp >= auctionEndTime,
            "Auction cannot be ended yet"
        );
        require(!auctionEnded, "Auction already ended");

        auctionEnded = true;
        emit AuctionEnded(highestBidder, highestBid);

        refundUsers();
    }

    function _processRefund(address _user) internal returns (bool) {
        require(_user != highestBidder, "Winner cannot withdraw refund");
        require(totalDepositedByUser[_user] > 0, "No refund available");

        uint256 totalDeposited = totalDepositedByUser[_user];
        uint256 commissions = (totalDeposited * COMMISSION_RATE) / 100;
        uint256 amountToRefund = totalDeposited - commissions;

        (bool success, ) = payable(_user).call{value: amountToRefund}("");

        if (success) {
            totalDepositedByUser[_user] = 0;
            emit RefundIssued(_user, amountToRefund);
        } else {
            emit RefundFailed(_user, amountToRefund);
        }

        return success;
    }

    function refundUsers() public onlyOwner isAuctionFinished hasAWinner {
        for (uint256 i = 0; i < participants.length; i++) {
            address currentBidder = participants[i];
            if (currentBidder != highestBidder) {
                _processRefund(currentBidder);
            }
        }
    }

    function withdrawRefund() external isAuctionFinished {
        bool success = _processRefund(msg.sender);
        require(success, "Manual refund failed");
    }

    function partialRefund() external isAuctionActive {
        require(bidsByUser[msg.sender].length > 1, "Need multiple bids");
        require(lastValidUserBid[msg.sender] > 0, "No valid bids");

        uint256 availableRefund = totalDepositedByUser[msg.sender] -
            lastValidUserBid[msg.sender];

        require(availableRefund > 0, "No refund available");

        uint256 commission = (availableRefund * COMMISSION_RATE) / 100;
        uint256 amountToRefund = availableRefund - commission;

        (bool success, ) = payable(msg.sender).call{value: amountToRefund}("");

        if (success) {
            totalDepositedByUser[msg.sender] = lastValidUserBid[msg.sender];
            emit RefundIssued(msg.sender, amountToRefund);
        } else {
            emit RefundFailed(msg.sender, amountToRefund);
        }
    }

    function getWinner() external view returns (address, uint256) {
        return (highestBidder, highestBid);
    }

    function getAllBids() external view returns (Bid[] memory) {
        return bids;
    }

    function getUserBids(
        address _user
    ) external view returns (UserBid[] memory) {
        return bidsByUser[_user];
    }

    function getUserTotalAmount(address _user) external view returns (uint256) {
        return totalDepositedByUser[_user];
    }

    receive() external payable {
        revert("Use bid() function to participate");
    }

    fallback() external payable {
        revert("Use bid() function to participate");
    }
}
