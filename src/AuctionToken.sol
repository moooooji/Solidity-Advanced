// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract AuctionToken is ERC20 {

    constructor(uint256 initialSupply) ERC20("UPSIDE", "UP") {
        _mint(msg.sender, initialSupply * (10 ** decimals())); // 초기 공급량 설정
    }
    
}