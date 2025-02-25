// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "forge-std/Test.sol";
import "../src/NFTAuctionV1.sol";
import "../src/TestNFT.sol";

contract NFTAuctionTest is Test {

    address public seller;
    address public bidder;
    uint256 public tokenId;
    address nft_address;

    NFTAuctionV1 auction; 
    TestNFT nft;
    
    function setUp() public {

        seller = address(1);
        bidder = address(2);

        auction = new NFTAuctionV1();
        nft = new TestNFT();


        vm.prank(seller); // mint by seller
        nft.mint(seller);

        deal(address(this), 100 ether);
        deal(seller, 100 ether);
        deal(bidder, 100 ether);

        auction.initialize();

    }

    function testCreateAution() public {
        vm.prank(seller); // msg.sender seller로 설정
        auction.createAution{value: 0.001 ether}(address(nft), 1, 0.1 ether);
    }

    // function testStartAuction() public {

    // }
    // function testApproveNFT() public {

    // }
    // function testFinalizeAuction() public {

    // }
    // function testBuyNFT() public {

    // }
    // function testBid() public {

    // }
    // function testWithdraw() public {

    // }
    // function testMulticall() public {

    // }
}