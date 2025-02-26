// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "./ERC1967Proxy.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import "forge-std/console.sol";

contract NFTAuctionProxy is ERC1967Proxy {

    constructor(address _implementationAddr, bytes memory _data) ERC1967Proxy(_implementationAddr, _data) {
        console.log("parameter imple: ", _implementationAddr);
        console.log("setted imple: ",_implementation());
    }

    function updateImple(address _newImpl, bytes memory _data) external {
        _upgradeToAndCall(_newImpl, _data);
    }
    

}