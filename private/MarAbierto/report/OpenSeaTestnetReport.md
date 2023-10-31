# NFT Collection Test Deployment Report

## Overview

This report confirms the successful deployment and testing of our Non-Fungible Token (NFT) collection using the Remix Ethereum IDE. We further validated the success of this operation by verifying that the content was correctly indexed on OpenSea, a popular marketplace for NFT trading. 

## Transaction Details

The NFT collection deployment was performed on Ethereum (Goerli Testnet) blockchain. The following are the details of the transaction:

- **Transaction Hash**: `0x346412f1570d96db77b4cf299750dd7445e1934784daf42e050ecd44c8ce1344`

Please note, this transaction hash is a unique identifier and can be used to trace the transaction details on any Ethereum blockchain explorer like [Etherscan](https://etherscan.io).

## OpenSea Testnet Exploration

You have the ability to inspect the test NFT collection interactively in a safe, simulated environment on OpenSea's testnet. This environment allows you to gain firsthand experience with the collection without any real-world implications.

Visit the following link to explore  'Mar Abierto Non-Fungible Time 2' test collection:

[Mar Abierto Non-Fungible Time 2](https://testnets.opensea.io/collection/mar-abierto-non-fungible-time-2)


## Testing Procedure and Results

The testing process was carried out in a step-by-step manner to ensure the successful deployment of the NFT collection and its correct indexing on OpenSea.

1. **Smart Contract Deployment**: The NFT smart contract was first deployed using Remix Ethereum IDE. This process compilation, and then deployment on the Ethereum testnet. The successful deployment was confirmed with the transaction hash provided.

2. **Metadata Upload**: Following the deployment, the NFT metadata was uploaded. This includes all the relevant information regarding the NFT such as its name, description, image, attributes, etc. The upload was successful, but a warning was encountered. 

    **Warning**: During the review, it was found that the `tokenURI` function (in is_reveal = false) is returning the `baseURI` without the token ID appended to it. This  lead to incorrect fetching of the metadata for the tokens. This issue needs to be resolved for correct functionality.

3. **OpenSea Indexing**: Post the metadata upload, the NFT collection was monitored on OpenSea Testnet for correct indexing. OpenSea, being a dominant player in the NFT marketplace, its correct indexing is a good indicator of the successful deployment and functioning of the NFTs. The NFTs from the collection appeared correctly on OpenSea when (is reveal = true).

    **Warning**: Because of the metadata issue, the collection preReveal metadata has not been tested. This needs to be addressed before further testing can continue.

# Conclusion
Deterministically, the tokens are minted in order, but in the opensea testnet, if you order them by oldest, there a some which are not consistent with the tokenID order as it can be seen [here](https://testnets.opensea.io/collection/mar-abierto-non-fungible-time-2?search[sortBy]=CREATED_DATE).
This is even more obvious when you zoom out the window.
In conclusion, the testing process confirmed that the NFT collection deployment was partly successful due for the noted warning.

NOTE: Due to the low nature of IPFS indexing content, the metadata will be appearing slowly and will take some time for all the cards to be displayed with their corresponding .gif.