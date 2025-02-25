// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "forge-std/Test.sol";
import "../src/NFTAuctionV1.sol";

contract NFTAuctionTest is Test {

    enum AuctionState {Created, Active, Ended}

    event Created(
        address indexed seller,
        address indexed nftAddress,
        uint256 indexed tokenId,
        uint256 minPrice,
        AuctionState state 
    );

    event Active(
        uint256 startTime,
        AuctionState state
    );

    event Ended(
        address indexed buyer,
        address indexed nftAddress,
        uint256 indexed tokenId,
        uint256 finalPrice,
        AuctionState state
    );

    struct Auction {
        address seller;
        address nftAddress;
        uint256 tokenId;
        uint256 minPrice;
        AuctionState state;
    }

    modifier nftOwner(
        address _nftAddress,
        uint256 _tokenId,
        address seller
    ) {
        IERC721 nft = IERC721(_nftAddress);
        address owner = nft.ownerOf(_tokenId);
        require(seller == owner, "Should be owner");
        _;
    }

    modifier checkApprove(
        address _nftAddress, 
        uint256 _tokenId,
        address seller
        ) {
        IERC721 nft = IERC721(_nftAddress);
        require(nft.getApproved(_tokenId) == address(this), "Not approved");
        _;
    }

    mapping(uint256 => Auction) public listings;
    mapping(address => uint256) public playerBid;

    address[] public bidders;

    uint256 public listingFee;
    uint256 public startTime;
    uint256 public tokenId;
    uint256 public currentBid; // 현재 입찰액
    address public highestBidder;
    bool private isStop;
    address public admin;
    
    function setUp() public {
        NFTAuctionV1 auction = new NFTAuctionV1();
        auction.initialize();

    }

    function testInitialize() public {

    }
    function testCreateAution() public {

    }
    function testStartAuction() public {

    }
    function testApproveNFT() public {

    }
    function testFinalizeAuction() public {

    }
    function testBuyNFT() public {

    }
    function testBid() public {

    }
    function testWithdraw() public {

    }
    function testMulticall() public {

    }
}