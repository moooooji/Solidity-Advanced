// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "forge-std/Test.sol";
import "../src/NFTAuctionV1.sol";
import "../src/TestNFT.sol";
import "forge-std/console.sol";
import "../src/NFTAuctionProxy.sol";

contract NFTAuctionTest is Test {

    address public seller;
    address public bidder;
    uint256 public tokenId;
    address nft_address;
    bytes[] public data;

    NFTAuctionProxy auctionProxy;
    NFTAuctionV1 auction; 
    TestNFT nft;
    
    function setUp() public {

        seller = address(1);
        bidder = address(2);

        tokenId = 1;

        auction = new NFTAuctionV1();
        nft = new TestNFT();

        bytes memory _data = abi.encodeWithSignature("initialize()");
        console.logBytes(_data);

        auctionProxy = new NFTAuctionProxy(address(auction), _data);

        vm.prank(seller); // mint by seller
        nft.mint(seller);

        deal(address(this), 100 ether);
        deal(seller, 100 ether);
        deal(bidder, 100 ether);

    }

    function testSetup() public {

    }

    function testCreateAuction() public {
        bytes memory _data;
        vm.prank(seller);
        _data = abi.encodeWithSignature("createAuction(address,uint256,uint256)", address(nft), tokenId, 0.1 ether);
        (bool result, ) = address(auctionProxy).call{value: 0.001 ether}(_data);
        require(result, "failed");
    }

    function testStartAuction() public {
        vm.prank(seller);
        nft.approve(address(auction), tokenId);

        vm.prank(seller);
        bytes memory _data;
        _data = abi.encodeWithSignature("startAuction(address,uint256,address)", address(nft), tokenId, seller);
        (bool result, ) = address(auctionProxy).call(_data);
        require(result, "failed");
    }
    function testBid() public {
        vm.prank(bidder);
        bytes memory _data;
        _data = abi.encodeWithSignature("bid(uint256)", tokenId);
        (bool result, ) = address(auctionProxy).call{value: 1 ether}(_data);
        require(result, "failed");
    }

    function testWithdraw() public {
        vm.prank(bidder);
        bytes memory _data;
        _data = abi.encodeWithSignature("bid(uint256)", tokenId);
        (bool result1, ) = address(auctionProxy).call{value: 1 ether}(_data);
        require(result1, "failed");

        vm.prank(bidder);
        _data = abi.encodeWithSignature("withdraw(uint256)", 1 ether);
        (bool result2, ) = address(auctionProxy).call(_data);
        require(result2, "failed");
    }

    function testFinalizeAuction() public {
        vm.prank(bidder);
        bytes memory _data;
        _data = abi.encodeWithSignature("bid(uint256)", tokenId);
        (bool result1, ) = address(auctionProxy).call{value: 1 ether}(_data);
        require(result1, "failed");

        skip(2 days);
        _data = abi.encodeWithSignature("finalizeAuction(uint256)", tokenId);
        (bool result2, ) = address(auctionProxy).call(_data);
        require(result2, "failed");
    }

    function testBuyNFT() public {
        vm.prank(seller);
        bytes memory _data;
        _data = abi.encodeWithSignature("createAuction(address,uint256,uint256)", address(nft), tokenId, 0.1 ether);
        (bool result1, ) = address(auctionProxy).call{value: 0.001 ether}(_data);
        require(result1, "failed 1");

        vm.prank(bidder);
        _data = abi.encodeWithSignature("bid(uint256)", tokenId);
        (bool result2, ) = address(auctionProxy).call{value: 1 ether}(_data);
        require(result2, "failed 2");

        skip(2 days);
        _data = abi.encodeWithSignature("finalizeAuction(uint256)", tokenId);
        (bool result3, ) = address(auctionProxy).call(_data);
        require(result3, "failed 3");
        
        vm.prank(bidder);
        _data = abi.encodeWithSignature("buyNFT(uint256)", tokenId);
        (bool result4, ) = address(auctionProxy).call(_data);
        require(result4, "failed 4");
    }
    
    function testMulticall() public {
        bytes[] memory _calldata = new bytes[](2);

        _calldata[0] = abi.encodeWithSignature("bid(uint256)", tokenId);
        _calldata[1] = abi.encodeWithSignature("withdraw(uint256)", 0.1 ether);

        bytes memory _data;
        _data = abi.encodeWithSignature("multicall(bytes[])", _calldata);
        vm.prank(bidder);
        (bool result, ) = address(auctionProxy).call{value: 0.1 ether}(_data);
        require(result, "failed ");
    }
    
}