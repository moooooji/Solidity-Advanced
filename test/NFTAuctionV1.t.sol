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
    address public bidder2;
    uint256 public tokenId;
    address nft_address;
    bytes[] public data;

    NFTAuctionProxy auctionProxy;
    NFTAuctionV1 auction; 
    TestNFT nft;
    
    function setUp() public {

        seller = address(1);
        bidder = address(2);
        bidder2 = address(3);

        tokenId = 1;

        auction = new NFTAuctionV1();
        nft = new TestNFT();

        bytes memory _data = abi.encodeWithSignature("initialize()");

        auctionProxy = new NFTAuctionProxy(address(auction), _data);

        vm.prank(seller); // mint by seller
        nft.mint(seller);

        deal(address(auction), 100 ether);
        deal(address(this), 100 ether);
        deal(seller, 100 ether);
        deal(bidder, 100 ether);
        deal(bidder2, 100 ether);

    }

    function testProxy() public {
        console.log("before bid, auctionProxy state variable: ", auctionProxy.currentBid());
        vm.prank(bidder);
        bytes memory _data;
        _data = abi.encodeWithSignature("bid(uint256,uint256,bool)", tokenId, 1 ether, false);
        (bool result, ) = address(auctionProxy).call{value: 1 ether}(_data);
        require(result, "failed");

        console.log("after bid, auctionProxy state variable: ", auctionProxy.currentBid());
    }

    function testPause() public {
        bytes memory _data;
        vm.prank(address(this));
        _data = abi.encodeWithSignature("pause()");
        (bool result1, ) = address(auctionProxy).call(_data);

        vm.prank(seller);
        _data = abi.encodeWithSignature("withdraw(uint256)", 0.1 ether);

        vm.expectRevert();
        (bool result2, ) = address(auctionProxy).call(_data);
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

    function testClaim() public {
        bytes memory _data;

        vm.prank(seller);
        _data = abi.encodeWithSignature("createAuction(address,uint256,uint256)", address(nft), tokenId, 0.1 ether);
        (bool result, ) = address(auctionProxy).call{value: 0.001 ether}(_data);
        require(result, "failed");

        vm.prank(seller);
        nft.approve(address(auction), tokenId);

        vm.prank(seller);
        _data = abi.encodeWithSignature("startAuction(address,uint256,address)", address(nft), tokenId, seller);
        (bool result1, ) = address(auctionProxy).call(_data);
        require(result1, "failed");

        _data = abi.encodeWithSignature("distributeProfits()");
        (bool result3, ) = address(auctionProxy).call(_data);
        require(result3, "failed");

        vm.prank(seller);
        _data = abi.encodeWithSignature("claimProfits()");
        (bool result4, ) = address(auctionProxy).call(_data);
        require(result4, "failed");
    }

    function testBid() public {
        vm.prank(bidder);
        bytes memory _data;
        _data = abi.encodeWithSignature("bid(uint256,uint256,bool)", tokenId, 1 ether, false);
        (bool result, ) = address(auctionProxy).call{value: 1 ether}(_data);
        require(result, "failed");
    }

    function testWithdraw() public {
        vm.prank(bidder);
        bytes memory _data;
        _data = abi.encodeWithSignature("bid(uint256,uint256,bool)", tokenId, 1 ether, false);
        (bool result1, ) = address(auctionProxy).call{value: 1 ether}(_data);
        require(result1, "failed");

        vm.prank(bidder);
        _data = abi.encodeWithSignature("withdraw(uint256,bool)", 1 ether, false);
        (bool result2, ) = address(auctionProxy).call(_data);
        require(result2, "failed");

        vm.prank(bidder);
        _data = abi.encodeWithSignature("withdraw(uint256)", 2 ether);
        vm.expectRevert();
        (bool result3, ) = address(auctionProxy).call(_data);
        require(result3, "failed");
    }

    function testFinalizeAuction() public {
        vm.prank(bidder);
        bytes memory _data;
        _data = abi.encodeWithSignature("bid(uint256,uint256,bool)", tokenId, 1 ether, false);
        (bool result1, ) = address(auctionProxy).call{value: 1 ether}(_data);
        require(result1, "failed");

        skip(2 days);
        vm.prank(bidder);
        _data = abi.encodeWithSignature("finalizeAuction(uint256)", tokenId);
        (bool result2, ) = address(auctionProxy).call(_data);
        require(result2, "failed");
    }
    
    function testMulticall() public {
        bytes[] memory _calldata = new bytes[](2);

        _calldata[0] = abi.encodeWithSignature("bid(uint256,uint256,bool)", tokenId, 0.1 ether, false);
        _calldata[1] = abi.encodeWithSignature("bid(uint256,uint256,bool)", tokenId, 2 ether, false);

        bytes memory _data;
        _data = abi.encodeWithSignature("multicall(bytes[])", _calldata);
        vm.prank(bidder);
        (bool result1, ) = address(auctionProxy).call{value: 2.1 ether}(_data);
        require(result1, "failed ");

        vm.prank(bidder);
        skip(2 days);
        _data = abi.encodeWithSignature("finalizeAuction(uint256)", tokenId);
        (bool result2, ) = address(auctionProxy).call(_data);
        require(result2, "failed ");
    }

    function testExploit() public {
        bytes[] memory _calldata = new bytes[](2);

        _calldata[0] = abi.encodeWithSignature("bid(uint256,uint256,bool)", tokenId, 1 ether, false);
        _calldata[1] = abi.encodeWithSignature("bid(uint256,uint256,bool)", tokenId, 2 ether, false);

        bytes memory _data;
        _data = abi.encodeWithSignature("multicall(bytes[])", _calldata);
        vm.prank(bidder);
        (bool result1, ) = address(auctionProxy).call{value: 3 ether}(_data);
        require(result1, "failed ");

        _calldata[0] = abi.encodeWithSignature("bid(uint256,uint256,bool)", tokenId, 3 ether, false);
        _calldata[1] = abi.encodeWithSignature("bid(uint256,uint256,bool)", tokenId, 3 ether, false);

        _data = abi.encodeWithSignature("multicall(bytes[])", _calldata);
        vm.prank(bidder2);
        (bool result2, ) = address(auctionProxy).call{value: 6 ether}(_data);
        require(result2, "failed 1");

        vm.prank(bidder);
        _data = abi.encodeWithSignature("withdraw(uint256,bool)", 7 ether, false);
        vm.expectRevert();
        (bool result3, ) = address(auctionProxy).call(_data);
        require(result3, "failed 2");

        vm.prank(bidder);
        _data = abi.encodeWithSignature("withdraw(uint256,bool)", 6 ether, false);
        (bool result4, ) = address(auctionProxy).call(_data);
        require(result4, "failed 3");
    }
    
}