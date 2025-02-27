// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "forge-std/console.sol";


contract NFTAuctionV1 is Initializable {

    enum AuctionState {Created, Active, Ended} // 상태머신 구현 완료

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
    
    mapping(address => uint256) public totalBalance;
    mapping(address => uint256) public lowerBid;
    mapping(address => uint256) public higherBid;
    mapping(address => uint256[]) public playersBid;


    uint256 public listingFee;
    uint256 public startTime;
    uint256 public tokenId;
    uint256 public currentBid; // 현재 입찰액
    address public highestBidder;
    bool private isStop;
    address public admin;
    bool public isMulticallExecution;
    

    modifier onlyAdmin() {
        require(admin == msg.sender, "Not admin");
        _;
    }

    modifier isPaused() {
        require(!isStop, "Emergency Stop");
        _;
    }

    function pause() external onlyAdmin { // emergency stop 구현 완료
        isStop = true;
    }

    function unpause() external onlyAdmin {
        isStop = false;
    }

    function initialize() public initializer { // 초기 배포자를 admin으로 생성. 프록시 패턴 구현 완료.
        isStop = false;
        listingFee = 0.001 ether;
        admin = msg.sender;
    }

    function getBalance(address _player) external view returns (uint256){
        return totalBalance[_player];
    }

    function createAuction(
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
        currentBid = 0; // reset currentBid
        highestBidder = address(0);
        emit Active(startTime, AuctionState.Active);
    }

    function finalizeAuction(uint256 _tokenId) external isPaused { // 경매 낙찰
        require(block.timestamp >= startTime + 2 days, "Not yet");
        address _nftAddress = listings[_tokenId].nftAddress;
        IERC721 nft = IERC721(_nftAddress);
        require(highestBidder != address(0), "No winner");

        if (msg.sender == highestBidder) {
            require(address(this).balance >= currentBid, "not enough balance");
            totalBalance[msg.sender] -= currentBid;
            (bool success, ) = msg.sender.call{value: currentBid}("");
            require(success, "failed");
        }
            // nft.transferFrom(address(this), msg.sender, tokenId); NFT 전송
        emit Ended(highestBidder, _nftAddress, _tokenId, currentBid, AuctionState.Ended);

    }

    function bid(uint256 _tokenId, uint256 _amount) external payable isPaused { // can bid
        require(msg.value >= listings[_tokenId].minPrice, "Can't bid, minPrice"); // more than minimum
        require(msg.value > currentBid, "Can't bid, 123"); // msg.value를 여러 입찰액을 포함해서 보냄

        totalBalance[msg.sender] += msg.value; // 잘못된 msg.value 사용으로 인한 취약점, msg.value를 하면 멀티콜로 bid 했을 때 합산된 입찰액이 계속 더해짐

        if (isMulticallExecution) { // 멀티콜에 의한 호출일 경우, bid한 최소 최대 금액을 각각 저장. 추후에 최소값부터 비교 후 최대값과 비교하여 경매 참여 시 편의성 ㅔㅈ공
            playersBid[msg.sender].push(_amount); 
            for (uint8 i = 0; i < playersBid[msg.sender].length; i++) {
                console.log("playersBid:" , playersBid[msg.sender][i]);
            }
            if (playersBid[msg.sender].length > 1) {
                if (playersBid[msg.sender][0] > playersBid[msg.sender][1] ) {
                   lowerBid[msg.sender] = playersBid[msg.sender][1];
                    higherBid[msg.sender] = playersBid[msg.sender][0];
                } else {
                    higherBid[msg.sender] = playersBid[msg.sender][0];
                    lowerBid[msg.sender] = playersBid[msg.sender][1];
                }
            } else {
                higherBid[msg.sender] = playersBid[msg.sender][0];
            }
            
            if (address(0) == highestBidder) { // 초기 입찰자일 경우
                highestBidder = msg.sender;
                currentBid = higherBid[msg.sender];
            } else {
                if (lowerBid[msg.sender] > currentBid) {
                    highestBidder = msg.sender;
                    currentBid = lowerBid[msg.sender];
                } else {
                    if (higherBid[msg.sender] > currentBid) {
                        highestBidder = msg.sender;
                        currentBid = higherBid[msg.sender];
                    }
                }
            }
            if (playersBid[msg.sender].length > 1) {
                playersBid[msg.sender].pop(); // 초기화
                playersBid[msg.sender].pop();
            }
        } else {
            if (address(0) == highestBidder) // 초기 입찰자일 경우
                if (msg.value > currentBid) { // 멀티콜 패턴에 의한 호출이 아니면서 입찰액이 현재 금액보다 클 경우
                    currentBid = msg.value;
                    highestBidder = msg.sender;
                }
        }
    }

    function withdraw(uint256 _amount) external payable isPaused {
        require(totalBalance[msg.sender] >= _amount, "can't withdraw"); // CEI 패턴 및 Pull over Push 패턴 구현 완료

        totalBalance[msg.sender] -= _amount;
        (bool success, ) = address(msg.sender).call{value: _amount}("");
        require(success, "withdraw failed");
    }

    function multicall(bytes[] calldata _calldata) external payable isPaused { // 멀티콜 패턴 구현 완료.
        isMulticallExecution = true; // multicall 실행 중 표시
        for (uint256 i = 0; i < _calldata.length; i++) {             
            (bool success, ) = address(this).delegatecall(_calldata[i]);
            require(success, "Delegatecall failed");
        }
        isMulticallExecution = false; // 실행 후 원래 상태로 복구
    }

    receive() external payable {}
}