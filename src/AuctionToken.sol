// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract AuctionToken is ERC20 {
    address public admin;
    constructor(uint256 initialSupply) ERC20("UPSIDE", "UP") {
        _mint(msg.sender, initialSupply * (10 ** decimals())); // 초기 공급량 설정
        admin = msg.sender;
    }
    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin");
        _;
    }

    function mint(address to, uint256 amount) external onlyAdmin {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external onlyAdmin {
        _burn(from, amount);
    }
    
}