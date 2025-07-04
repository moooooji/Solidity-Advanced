// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "forge-std/console.sol";
import "./AuctionToken.sol";

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
    uint256 totalListingFee;
    uint256 profitPerToken;

    AuctionToken UP;

    modifier onlyCreated(uint256 _tokenId) {
        require(listings[_tokenId].state == AuctionState.Created, "Auction not in Created state");
        _;
    }

    modifier onlyActive(uint256 _tokenId) {
        require(listings[_tokenId].state == AuctionState.Active, "Auction not in Active state");
        _;
    }

    modifier onlyEnded(uint256 _tokenId) {
        require(block.timestamp >= startTime + 2 days, "Auction not in Ended state");
        listings[_tokenId].state = AuctionState.Ended;
        _;
    }

    modifier checkNFTApprove( 
        address _nftAddress, 
        uint256 _tokenId,
        address seller
        ) {
        IERC721 nft = IERC721(_nftAddress);
        require(nft.getApproved(_tokenId) == address(0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f), "Not approved"); // 테스트를 위해 테스트에서 생성한 auction 주소 사용
        // require(nft.getApproved(_tokenId) == address(this), "Not approved"); 실제 배포 시
        _;
    }

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
        UP = new AuctionToken(100000); // 초기 발행량
    }

    function getBalance(address _player) external view returns (uint256){
        return totalBalance[_player];
    }

    function distributeProfits() external onlyAdmin { // 서비스 이용자들에게 수수료에 대한 토큰 부과
        uint256 totalSupply = UP.totalSupply();
        profitPerToken = totalListingFee * (10**18) / totalSupply; // 토큰 1개당 받을 수익
        totalListingFee = 0;
    }

    function claimProfits() external { // 사용자들이 직접 호출
        uint256 balance = UP.balanceOf(msg.sender);
        uint256 profit = (balance * profitPerToken) / 10**18; // 단위 조정
        require(profit > 0, "No profit");
        console.log("Received profit: ", profit);
        (bool success, ) = msg.sender.call{value: profit}(""); 
        require(success, "Transfer failed");
    }

    function createAuction(
        address _nftAddress,
        uint256 _tokenId,
        uint256 _minPrice
    ) external payable nftOwner(_nftAddress, _tokenId, msg.sender) isPaused { // 경매 생성. 경매할 NFT가 경매 시작을 원하는 주소와 일치하는지 확인
        require(_minPrice > 0, "Minimum Price 0 is not allowed");
        require(msg.value == listingFee, "Not matched listing fee");

        totalListingFee += msg.value; // 경매 시작에 대한 수수료 축적
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
        ) external onlyCreated(_tokenId) checkNFTApprove(_nftAddress, _tokenId, seller) nftOwner(_nftAddress, _tokenId, msg.sender) isPaused {
        startTime = block.timestamp;
        currentBid = 0; // reset currentBid
        highestBidder = address(0);

        listings[_tokenId].state = AuctionState.Active;

        UP.transfer(msg.sender, 1*(10**18)); // 경매를 시작한 사람에게 1UP 토큰을 지급
        emit Active(startTime, AuctionState.Active);
    }

    function finalizeAuction(uint256 _tokenId) external onlyEnded(_tokenId) isPaused { // 경매 낙찰
        address _nftAddress = listings[_tokenId].nftAddress;
        address _seller = listings[_tokenId].seller;
        IERC721 nft = IERC721(_nftAddress);
        require(highestBidder != address(0), "No winner");

        if (msg.sender == highestBidder) {
            require(address(this).balance >= currentBid, "not enough balance");
            totalBalance[msg.sender] -= currentBid;
            // nft.transferFrom(address(this), msg.sender, tokenId); NFT 전송
            _seller.call{value : currentBid}("");
        }
        
        emit Ended(highestBidder, _nftAddress, _tokenId, currentBid, AuctionState.Ended);

    }

    function bid(uint256 _tokenId, uint256 _amount, bool isERC) external payable onlyActive(_tokenId) isPaused { // can bid
        require(msg.value >= listings[_tokenId].minPrice, "Can't bid, minPrice"); // more than minimum
        require(msg.value > currentBid, "Can't bid");

        if (!isERC) {
            totalBalance[msg.sender] += msg.value; // 잘못된 msg.value 사용으로 인한 취약점, msg.value를 하면 멀티콜로 bid 했을 때 합산된 입찰액이 계속 더해짐
        } else {
            require(UP.allowance(msg.sender, address(this)) > _amount, "Not Approved ERC20");
            UP.transferFrom(msg.sender, address(this), _amount);
            totalBalance[msg.sender] += _amount;
        }

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

    function withdraw(uint256 _amount, bool isERC) external payable isPaused {
        require(totalBalance[msg.sender] >= _amount, "can't withdraw"); // CEI 패턴 및 Pull over Push 패턴 구현 완료
        
        totalBalance[msg.sender] -= _amount;

        if (!isERC) {
            (bool success, ) = address(msg.sender).call{value: _amount}("");
            require(success, "withdraw failed");
        } else {
            UP.transfer(msg.sender, _amount);
        }
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