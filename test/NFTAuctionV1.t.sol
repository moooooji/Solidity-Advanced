// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "forge-std/Test.sol";
import "../src/NFTAuctionV1.sol";
import "../src/TestNFT.sol";
import "forge-std/console.sol";

contract NFTAuctionTest is Test {

    address public seller;
    address public bidder;
    uint256 public tokenId;
    address nft_address;
    bytes[] public data;


    NFTAuctionV1 auction; 
    TestNFT nft;
    
    function setUp() public {

        seller = address(1);
        bidder = address(2);

        tokenId = 1;

        auction = new NFTAuctionV1();
        nft = new TestNFT();


        vm.prank(seller); // mint by seller
        nft.mint(seller);

        deal(address(this), 100 ether);
        deal(seller, 100 ether);
        deal(bidder, 100 ether);

        auction.initialize();

    }

    function testCreateAuction() public {
        vm.prank(seller); // msg.sender seller로 설정
        auction.createAution{value: 0.001 ether}(address(nft), tokenId, 0.1 ether);
    }

    function testStartAuction() public {
        vm.prank(seller); // 판매자가 직접 approve
        nft.approve(address(auction), tokenId);
        vm.prank(seller); // 경매 시작
        auction.startAuction(address(nft), tokenId, seller);
    }
    function testBid() public {
        vm.prank(bidder);
        auction.bid{value: 1 ether}(tokenId);
    }

    function testWithdraw() public {
        vm.prank(bidder);
        auction.bid{value: 1 ether}(tokenId);
        vm.prank(bidder);
        auction.withdraw(1 ether);
    }
    function testFinalizeAuction() public {
        vm.prank(bidder);
        auction.bid{value: 1 ether}(tokenId);
        skip(2 days);
        auction.finalizeAuction(tokenId);
    }

    function testBuyNFT() public {
        vm.prank(seller);
        auction.createAution{value: 0.001 ether}(address(nft), tokenId, 0.1 ether);
        vm.prank(bidder);
        auction.bid{value: 1 ether}(tokenId);
        skip(2 days);
        auction.finalizeAuction(tokenId);
        vm.prank(bidder);
        auction.buyNFT(tokenId);
    }
    
    
    function testMulticall() public {
        vm.prank(bidder);
        data.push(abi.encodeWithSignature("bid(uint256)", tokenId));
        data.push(abi.encodeWithSignature("withdraw(uint256)", 1 ether));

        auction.multicall{value: 1 ether}(data);
    }
    
}