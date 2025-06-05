// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title Auction Smart Contract
 * @author Robert Rondón
 * @notice This contract implements an auction system with refunds and commission handling
 */
contract Auction {
    // ============================================================================
    // CONSTANTS
    // ============================================================================

    /// @notice Commission rate charged on refunds (2%)
    uint256 public constant COMMISSION_RATE = 2; // 2%

    /// @notice Minimum bid increment required (5% above current highest bid)
    uint256 public constant MIN_BID_INCREMENT = 5; // 5%

    /// @notice Time extension when bid is placed in last 10 minutes
    uint256 public constant TIME_EXTENSION = 10 minutes;

    // ============================================================================
    // STATE VARIABLES
    // ============================================================================

    /// @notice Indicates if the auction has been manually ended
    bool public auctionEnded;

    /// @notice Unix timestamp when the auction ends
    uint256 public auctionEndTime;

    /// @notice Address of the auction owner/creator
    address public owner;

    /// @notice Current highest bid amount
    uint256 public highestBid;

    /// @notice Address of the current highest bidder
    address public highestBidder;

    // ============================================================================
    // STRUCTS
    // ============================================================================

    /**
     * @notice Structure to store individual bid information
     * @param bidder Address of the bidder
     * @param bidAmount Amount of the bid in wei
     * @param timestamp Unix timestamp when the bid was placed
     */
    struct Bid {
        address bidder;
        uint256 bidAmount;
        uint256 timestamp;
    }

    /**
     * @notice Structure to store user-specific bid information
     * @param bidAmount Amount of the bid in wei
     * @param timestamp Unix timestamp when the bid was placed
     */
    struct UserBid {
        uint256 bidAmount;
        uint256 timestamp;
    }

    // ============================================================================
    // STORAGE ARRAYS AND MAPPINGS
    // ============================================================================

    /// @notice Array containing all bids placed in the auction
    Bid[] public bids;

    /// @notice Array containing addresses of all auction participants
    address[] public participants;

    /// @notice Mapping to store all bids made by each user
    mapping(address user => UserBid[] bidsMade) public bidsByUser;

    /// @notice Mapping to check if a user has participated in the auction
    mapping(address user => bool participated) public hasParticipated;

    /// @notice Mapping to store the last valid bid amount for each user
    mapping(address user => uint256 amount) public lastValidUserBid;

    /// @notice Mapping to track total amount deposited by each user
    mapping(address user => uint256 totalAmount) public totalDepositedByUser;

    // ============================================================================
    // EVENTS
    // ============================================================================

    /**
     * @notice Emitted when the auction ends
     * @param winner Address of the winning bidder
     * @param amount Winning bid amount
     */
    event AuctionEnded(address winner, uint256 amount);

    /**
     * @notice Emitted when a new bid is placed
     * @param bidder Address of the bidder
     * @param amount Amount of the bid
     */
    event NewBid(address indexed bidder, uint amount);

    /**
     * @notice Emitted when a refund fails
     * @param bidder Address that should have received the refund
     * @param amount Amount that failed to be refunded
     */
    event RefundFailed(address indexed bidder, uint256 amount);

    /**
     * @notice Emitted when a refund is successfully issued
     * @param bidder Address receiving the refund
     * @param amount Amount refunded (after commission)
     */
    event RefundIssued(address indexed bidder, uint256 amount);

    // ============================================================================
    // MODIFIERS
    // ============================================================================

    /**
     * @notice Restricts function access to the auction owner only
     */
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner has permission");
        _;
    }

    /**
     * @notice Ensures the auction is currently active
     */
    modifier isAuctionActive() {
        require(block.timestamp < auctionEndTime, "Auction has ended.");
        require(!auctionEnded, "Auction already ended.");
        _;
    }

    /**
     * @notice Ensures the auction has finished
     */
    modifier isAuctionFinished() {
        require(block.timestamp > auctionEndTime, "Auction is still ongoing.");
        require(auctionEnded, "Auction is not ended.");
        _;
    }

    /**
     * @notice Ensures there is a valid winner
     */
    modifier hasAWinner() {
        require(highestBidder != address(0), "There is no winner");
        _;
    }

    // ============================================================================
    // CONSTRUCTOR
    // ============================================================================

    /**
     * @notice Initializes the auction contract
     * @dev Sets the auction duration and owner address
     * @param _durationMinutes Duration of the auction in minutes (max 1 week)
     */
    constructor(uint256 _durationMinutes) {
        require(_durationMinutes > 0, "Duration must be positive");
        require(_durationMinutes <= 10080, "Duration too long"); // Max 1 week
        owner = msg.sender;
        auctionEndTime = block.timestamp + (_durationMinutes * 60);
    }

    // ============================================================================
    // MAIN FUNCTIONS
    // ============================================================================

    /**
     * @notice Places a bid in the auction
     * @dev Bid must be at least 5% higher than current highest bid
     * @dev Automatically extends auction if bid is placed within last 10 minutes
     * @dev Tracks user participation and updates all relevant mappings
     */
    function bid() external payable isAuctionActive {
        require(msg.value > 0, "Bid amount must be greater than zero");
        require(
            msg.value >= highestBid + ((highestBid * MIN_BID_INCREMENT) / 100),
            "Bid must be at least 5% higher than current highest"
        );

        // Linking bids to an user
        bidsByUser[msg.sender].push(
            UserBid({bidAmount: msg.value, timestamp: block.timestamp})
        );

        // Setting the bid as the valid one
        lastValidUserBid[msg.sender] = msg.value;

        // Updating total user deposited amount
        totalDepositedByUser[msg.sender] += msg.value;

        // Adding new to allBids array
        bids.push(
            Bid({
                bidder: msg.sender,
                bidAmount: msg.value,
                timestamp: block.timestamp
            })
        );

        // Setting bid winner value and address
        highestBid = msg.value;
        highestBidder = msg.sender;

        // Verify if is necessary to add user to participants array
        if (!hasParticipated[msg.sender]) {
            participants.push(msg.sender);
            hasParticipated[msg.sender] = true;
        }

        // Implement time extension if applies
        if (auctionEndTime - block.timestamp < 10 minutes) {
            auctionEndTime = block.timestamp + TIME_EXTENSION;
        }

        // Succesful bid
        emit NewBid(highestBidder, highestBid);
    }

    /**
     * @notice Manually ends the auction (owner only)
     * @dev Can only be called after the auction end time has passed
     * @dev Automatically processes refunds for all non-winning participants
     */
    function endAuction() external onlyOwner {
        require(
            block.timestamp >= auctionEndTime,
            "Auction cannot be ended yet"
        );
        require(!auctionEnded, "Auction already ended");

        // If the end time passed, set the action as ended and refund users
        auctionEnded = true;

        // Auction is finished
        emit AuctionEnded(highestBidder, highestBid);

        // Tries to refund non-winning participants
        refundUsers();
    }

    /**
     * @notice Issues refunds to all non-winning participants (owner only)
     * @dev Deducts 2% commission from each refund
     * @dev Can only be called after auction has ended
     */
    function refundUsers() public onlyOwner isAuctionFinished hasAWinner {
        for (uint256 i = 0; i < participants.length; i++) {
            address currentBidder = participants[i];
            if (currentBidder != highestBidder) {
                _processRefund(currentBidder);
            }
        }
    }

    /**
     * @notice Allows users to manually withdraw their refund
     * @dev Can only be called after auction has ended
     * @dev Alternative to automatic refund processing
     */
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

    receive() external payable {
        revert("Use bid() function to participate");
    }

    fallback() external payable {
        revert("Use bid() function to participate");
    }
}
