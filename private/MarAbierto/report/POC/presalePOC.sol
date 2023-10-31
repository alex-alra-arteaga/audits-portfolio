// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

//Errors
error MarAbiertoToken__AllTokensAreMinted();
error MarAbiertoToken__CannotMintLegendaryNFT();
error MarAbiertoToken__InsufficientETHAmount();

// Implementar estandar ERC2981

// this is an implementation for sabing gass

contract MarAbiertoTokenPresalePOC is ERC721, Pausable, Ownable, ERC721Burnable {
    using Counters for Counters.Counter;

    Counters.Counter private s_tokenIdCounter;
    uint256 private s_supply = 50;
    uint256 private s_mintPrice = 0.1 ether;
    string private s_baseTokenURI;

    event NftMinted(uint256 indexed tokenId, address minter);

    constructor(string memory baseURI) ERC721("MarAbierto", "MAR") {
        setBaseURI(baseURI);
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return s_baseTokenURI;
    }

    function setBaseURI(string memory _baseTokenURI) public onlyOwner {
        s_baseTokenURI = _baseTokenURI;
    }

    function addSupply(uint256 _amount) public onlyOwner {
        s_supply += _amount;
    }

    function setMintPrice(uint256 _newMintPrice) public onlyOwner {
        s_mintPrice = _newMintPrice;
    }

    function mint(address to) public payable {
        if (s_tokenIdCounter.current() >= s_supply) {
            revert MarAbiertoToken__AllTokensAreMinted();
        }

        if (msg.value < s_mintPrice) {
            revert MarAbiertoToken__InsufficientETHAmount();
        }

        uint256 tokenId = s_tokenIdCounter.current();
        s_tokenIdCounter.increment();

        _safeMint(to, tokenId);

        emit NftMinted(tokenId, msg.sender);
    }

    function mintAmount(uint256 _amount) public payable {
        if (msg.value < s_mintPrice * _amount) {
            revert MarAbiertoToken__InsufficientETHAmount();
        }
        for (uint256 i = 0; i < _amount; i++) {
            mint(msg.sender);
        }
    }

    function mintOwner(address to) public payable onlyOwner {
        if (s_tokenIdCounter.current() >= s_supply) {
            revert MarAbiertoToken__AllTokensAreMinted();
        }

        uint256 tokenId = s_tokenIdCounter.current();
        s_tokenIdCounter.increment();

        _safeMint(to, tokenId);

        emit NftMinted(tokenId, msg.sender);
    }

    function mintAmountOwner(uint256 _amount) public payable onlyOwner {
        for (uint256 i = 0; i < _amount; i++) {
            mintOwner(msg.sender);
        }
    }

    function withdraw() public payable onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No ether left to withdraw");

        (bool success, ) = (msg.sender).call{value: balance}("");
        require(success, "Transfer failed.");
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    // An override that disables the transfer of NFTs if the smartcontract is paused
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    ) internal override whenNotPaused {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    function getSupply() public view returns (uint256) {
        return s_supply;
    }

    function getPrice() public view returns (uint256) {
        return s_mintPrice;
    }

    function getBaseURI() public view returns (string memory) {
        return s_baseTokenURI;
    }

    // This contract is a Proof of Concept (POC) for a presale of a non-fungible token (NFT) collection.
    // It's important to note that this is a possible implementation and may need adjustments based on specific requirements.
    // ---------------------- Presale ------------------------------//
    /** 
        @dev Possible implementation for the NFT collection presale
    **/

    // ! pseudo code -> not tested
    // Maximum possible integer value (2^256 - 1) --> all the bits set to 1
    uint256 private constant MAX_INT =
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;

    // Array to store ticket information. This example allows for 512 tickets (256 * 2)
    uint256[2] private arr = [MAX_INT, MAX_INT];

    // Function to handle the presale of tickets
    function presale(
        bytes calldata signature,
        uint256 ticketNumber
    ) public payable {
        // Verify the signature
        require(
            verifySig(msg.sender, ticketNumber, signature),
            "invalid signature"
        );

        // Check if the sent value is enough to mint the desired amount of tokens
        if (msg.value < s_mintPrice) {
            revert MarAbiertoToken__InsufficientETHAmount();
        }

        // Claim the ticket or block the transaction if the ticket is already claimed
        claimTicketOrBlockTransaction(ticketNumber);

        // Mint the token
        _mint(msg.sender, ticketNumber);
    }

    // Function to claim a ticket or block the transaction if the ticket is already claimed
    function claimTicketOrBlockTransaction(uint256 ticketNumber) internal {
        require(ticketNumber < arr.length * 256, "too large");
        uint256 storageOffset = ticketNumber / 256;
        uint256 offsetWithin256 = ticketNumber % 256;
        uint256 storedBit = (arr[storageOffset] >> offsetWithin256) &
            uint256(1);
        require(storedBit == 1, "already taken");

        arr[storageOffset] =
            arr[storageOffset] &
            ~(uint256(1) << offsetWithin256);
    }

    // Function to verify the signature
    function verifySig(
        address _address,
        uint256 _ticketNumber,
        bytes memory _signature
    ) internal view returns (bool) {
        // Prepare the data to be signed
        bytes32 hash = keccak256(abi.encodePacked(_address, _ticketNumber));

        // Recover the signer's address from the signature
        address recoveredAddress = recover(hash, _signature);

        // The signer's address must match the provided address
        return (_address == recoveredAddress);
    }

    // Function to recover the signer's address from the signature
    function recover(
        bytes32 hash,
        bytes memory signature
    ) internal pure returns (address) {
        bytes32 r;
        bytes32 s;
        uint8 v;

        // Check the signature length
        if (signature.length != 65) {
            return (address(0));
        }

        // Divide the signature into r, s and v variables
        assembly {
            r := mload(add(signature, 0x20))
            s := mload(add(signature, 0x40))
            v := byte(0, mload(add(signature, 0x60)))
        }

        // Version of signature should be 27 or 28, but 0 and 1 are also possible versions
        if (v < 27) {
            v += 27;
        }

        // If the version is not correct return zero address
        if (v != 27 && v != 28) {
            return (address(0));
        } else {
            // If the version is correct return the signer address
            return ecrecover(hash, v, r, s);
        }
    }
    // ---------------------- Presale ------------------------------//
}
