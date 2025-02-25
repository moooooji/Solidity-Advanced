// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TestNFT is ERC721 {
    uint256 private _tokenIdCounter;
    constructor() ERC721("Upside", "UP") {}

    function mint(address to) public {
        _tokenIdCounter += 1;
        _safeMint(to, _tokenIdCounter);
    }
}