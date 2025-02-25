// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "forge-std/console.sol";


contract NFTAuctionV1 is Initializable{

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

    modifier onlyAdmin() {
        require(admin == msg.sender, "Not admin");
        _;
    }

    modifier isPaused() {
        require(!isStop, "Emergency Stop");
        _;
    }

    function pause() external onlyAdmin {
        isStop = true;
    }

    function unpause() external onlyAdmin {
        isStop = false;
    }

    function initialize() public initializer {
        isStop = false;
        listingFee = 0.001 ether;
        admin = msg.sender;
    }

    function createAution(
        address _nftAddress,
        uint256 _tokenId,
        uint256 _minPrice
    ) external payable nftOwner(_nftAddress, _tokenId, msg.sender) isPaused { // 경매 생성. 경매할 NFT가 경매 시작을 원하는 주소와 일치하는지 확인
        require(_minPrice > 0, "Minimum Price 0 is not allowed");
        require(msg.value == listingFee, "Not matched listing fee");

        tokenId = _tokenId;

        listings[_tokenId] = Auction({
            seller: msg.sender,
            nftAddress: _nftAddress,
            tokenId: tokenId,
            minPrice: _minPrice,
            state: AuctionState.Created
        });

        emit Created(msg.sender, _nftAddress, _tokenId, _minPrice, AuctionState.Created);
    }

    function startAuction(
        address _nftAddress,
        uint256 _tokenId,
        address seller
        ) external checkApprove(_nftAddress, _tokenId, seller) nftOwner(_nftAddress, _tokenId, msg.sender) isPaused {
        startTime = block.timestamp;

        emit Active(startTime, AuctionState.Active);
    }

    function finalizeAuction(uint256 _tokenId) external isPaused { // 경매 시간이 지나야만 호출 가능
        require(block.timestamp >= startTime + 2 days, "Not yet");
        for (uint16 i = 0; i < bidders.length; i++) {
            if (currentBid == playerBid[bidders[i]]) { // 가장 높은 입찰자 선정
                highestBidder = bidders[i];
                address _nftAddress = listings[_tokenId].nftAddress;
                emit Ended(highestBidder, _nftAddress, _tokenId, currentBid, AuctionState.Ended);
                break;
            }
        }
    }

    function buyNFT(uint256 _tokenId) external isPaused { // 최고 입찰액을 불러 낙찰된 사람만 호출 가능
        require(highestBidder == msg.sender, "not highestBidder");
        address _nftAddress = listings[_tokenId].nftAddress;
        IERC721 nft = IERC721(_nftAddress);

        // nft.transferFrom(address(this), msg.sender, tokenId); approve 문제 해결이 안됨
    }

    function bid(uint256 _tokenId) external payable isPaused { // 입찰
        require(msg.value >= listings[_tokenId].minPrice, "Can't bid"); // 최소 금액 이상이어야 입찰 가능
        require(msg.value > currentBid, "Can't bid");

        if (playerBid[msg.sender] == 0) { // 입찰 안한 사람만 배열에 저장
            bidders.push(msg.sender);
        }

        playerBid[msg.sender] += msg.value;
        currentBid = msg.value;
    }

    function withdraw(uint256 amount) external payable isPaused { // 입찰액에서 출금
        require(playerBid[msg.sender] >= amount, "Insufficient amount");
        playerBid[msg.sender] -= amount;
        (bool success, ) = address(msg.sender).call{value: amount}("");
        require(success, "withdraw failed!");
    }

    function multicall(bytes[] calldata _calldata) external isPaused {
        for (uint256 i = 0; i < _calldata.length; i++) {
            (bool success, ) = address(this).delegatecall(_calldata[i]);
            require(success, "Failed");
        }
    }
}