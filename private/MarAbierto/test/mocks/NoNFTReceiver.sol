// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

interface IERC721 {
    function mint(address to) external payable;
}

error NoNFTReceiver__MintFailed();

contract NoNFTReceiver {
    address public immutable nftAddress;
    constructor(address _nftAddress) payable {
        nftAddress = _nftAddress;
    }

    function mint() public {
        (bool success, ) = nftAddress.call{value: address(this).balance}(abi.encodeWithSelector(
            IERC721.mint.selector,
            address(this)
        ));
        if (!success) revert NoNFTReceiver__MintFailed();
    }
}

contract NFTReceiver {
    address public immutable nftAddress;
    constructor(address _nftAddress) payable {
        nftAddress = _nftAddress;
    }

    function mint() public {
        (bool success, ) = nftAddress.call{value: address(this).balance}(abi.encodeWithSelector(
            IERC721.mint.selector,
            address(this)
        ));
        require(success, "NFTReceiver: mint failed");
    }

    function onERC721Received(address, address, uint256, bytes calldata) external returns (bytes4) {
        return this.onERC721Received.selector;
    }

}