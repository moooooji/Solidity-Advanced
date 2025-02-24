// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "./ERC1967Proxy.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";

contract NFTAuctionProxy is ERC1967Proxy {

    constructor(address _implementationAddr, bytes memory _data) ERC1967Proxy(_implementationAddr, _data) {}

    function updateImple(address _newImpl, bytes memory _data) external {
        _upgradeToAndCall(_newImpl, _data);
    }
    

}