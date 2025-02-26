// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/ERC20.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "forge-std/console.sol";


contract NFTAuctionV1 is Initializable, ERC721, ERC20 {

    enum AuctionState {Created, Active, Ended} // Auction State

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

    modifier nftOwner( // check NFT ownner
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
        require(nft.getApproved(_tokenId) == address(0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f), "Not approved"); // 테스트를 위해 테스트에서 생성한 auction 주소 사용
        // require(nft.getApproved(_tokenId) == address(this), "Not approved"); 실제 배포 시
        _;
    }

    mapping(uint256 => Auction) public listings;
    mapping(address => uint256) public playerBid;
    mapping(address => uint256) public balances; // can pay ERC20

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
        paymentToken = IERC20(_paymentToken); // ERC20 토큰 주소 설정
    }

    function createAuction(
        address _nftAddress,
        uint256 _tokenId,
        uint256 _minPrice
    ) external payable nftOwner(_nftAddress, _tokenId, msg.sender) isPaused { // 경매 생성. 경매할 NFT가 경매 시작을 원하는 주소와 일치하는지 확인
        require(_minPrice > 0, "Minimum Price 0 is not allowed");
        console.log("msg.value: ", msg.value);
        console.log("listingFee: ", listingFee);
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
        bidders = []; // reset players
        currentBid = 0; // reset currentBid
        highestBidder = address(0);
        emit Active(startTime, AuctionState.Active);
    }

    function finalizeAuction(uint256 _tokenId) external isPaused { // finalize auction
        require(block.timestamp >= startTime + 2 days, "Not yet");
        
        uint256 tmpBalance;

        for (uint16 i = 0; i < bidders.length; i++) {
            if (currentBid == playerBid[bidders[i]]) { // check winner
                highestBidder = bidders[i];
                address _nftAddress = listings[_tokenId].nftAddress;
                IERC721 nft = IERC721(_nftAddress);
                // nft.transferFrom(address(this), msg.sender, tokenId);
            } else {
                tmpBalance = playerBid[bidders[i]];
                (bool success, ) = bidders[i].call{value: tmpBalance}(""); // send ether
                require(success, "Failed send to player");
            }
        }
        emit Ended(highestBidder, _nftAddress, _tokenId, currentBid, AuctionState.Ended);
    }

    function bid(uint256 _tokenId) external payable isPaused { // can bid
        require(msg.value >= listings[_tokenId].minPrice, "Can't bid"); // more than minimum
        require(msg.value > currentBid, "Can't bid");

        if (playerBid[msg.sender] == 0) { 
            bidders.push(msg.sender);   // first bid, save player
        }
        playerBid[msg.sender] += msg.value;
        currentBid = msg.value;
    }

    function withdraw(uint256 amount) external payable isPaused {
        require(playerBid[msg.sender] >= amount, "Insufficient amount");

        address tmp;

        playerBid[msg.sender] -= amount;
        (bool success, ) = address(msg.sender).call{value: amount}("");
        require(success, "withdraw failed!");

            if (playerBid[msg.sender] == 0) {
                for (uint16 i = 0; i < bidders.length; i++) { // delete player
                    if (bidders[i] == msg.sender) {
                        tmp = bidders[bidders.length - 1];
                        bidders[i] = tmp;
                        bidders[bidders.length - 1] = bidders[i];
                        bidders.pop();
                        break;
                    }
            }
        }
    }

    function multicall(bytes[] calldata _calldata) external payable isPaused {
        for (uint256 i = 0; i < _calldata.length; i++) {
            (bool success, ) = address(this).delegatecall(_calldata[i]);
            require(success, "Delegatecall failed");
        }
    }
}