// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "./ERC1967Proxy.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import "forge-std/console.sol";
import "./AuctionToken.sol";

contract NFTAuctionProxy is ERC1967Proxy {

    enum AuctionState {Created, Active, Ended}

    struct Auction {
        address seller;
        address nftAddress;
        uint256 tokenId;
        uint256 minPrice;
        AuctionState state;
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

    constructor(address _implementationAddr, bytes memory _data) ERC1967Proxy(_implementationAddr, _data) {}

    function updateImple(address _newImpl, bytes memory _data) external {
        _upgradeToAndCall(_newImpl, _data);
    }
    

}