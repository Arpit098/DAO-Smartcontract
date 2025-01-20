const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("MizzleMarket Contract", function () {
    let MizzleMarket, mizzleMarket;
    let owner, collector, keeper, user1, user2;
    let mizzlToken, usdt, daoToken;

    before(async function () {
        // Get contract factories and signers
        [owner, collector, keeper, user1, user2] = await ethers.getSigners();
        
        const Token = await ethers.getContractFactory("Token"); // Mock ERC20 tokens
        mizzlToken = await Token.deploy("Mizzle Token", "MIZZL", 18);
        usdt = await Token.deploy("USDT", "USDT", 18);
        daoToken = await Token.deploy("DAO Token", "DAO", 18);

        const MizzleMarketFactory = await ethers.getContractFactory("MizzleMarket");
        mizzleMarket = await MizzleMarketFactory.waitForDeployment();
        await mizzleMarket.initialize(owner.address,await collector.getAddress(), mizzlToken.address, daoToken.address, usdt.address, keeper.address);
    });

    it("should register a user", async function () {
        await mizzleMarket.connect(user1).register(1, owner.address);
        const userDetail = await mizzleMarket.UserDetail(1);

        expect(userDetail.id).to.equal(1);
        expect(userDetail.userAddresses[0]).to.equal(user1.address);
        expect(userDetail.sponsorAddress).to.equal(owner.address);
    });

    it("should mint NFTs and place them on the market", async function () {
        const price = ethers.utils.parseUnits("100", 18);
        const mizzleAmount = ethers.utils.parseUnits("50", 18);
        const daoAmount = ethers.utils.parseUnits("20", 18);
        
        await mizzleMarket.mint("https://nft-metadata.com", price, 10, mizzleAmount, daoAmount);

        const nftDetail = await mizzleMarket.NftDetails(1);
        expect(nftDetail.id).to.equal(1);
        expect(nftDetail.price).to.equal(price);
        expect(nftDetail.amount).to.equal(10);

        const marketItem = await mizzleMarket.MarketItemDetails(1);
        expect(marketItem.nftId).to.equal(1);
        expect(marketItem.price).to.equal(price);
        expect(marketItem.mizzleAmount).to.equal(mizzleAmount);
        expect(marketItem.daoAmount).to.equal(daoAmount);
    });

    it("should allow a registered user to buy a market item", async function () {
        const userId = 1;
        const nftId = 1;
        const price = ethers.utils.parseUnits("100", 18);
        
        await usdt.transfer(user1.address, price); // Give user1 some USDT
        await usdt.connect(user1).approve(mizzleMarket.address, price); // Approve the transfer

        const key = await mizzleMarket.connect(user1).getCode(userId);
        await mizzleMarket.connect(user1).BuyMarketItem(userId, nftId, key);

        const nftDetail = await mizzleMarket.NftDetails(nftId);
        expect(nftDetail.amount).to.equal(9); // After 1 purchase, 9 should remain

        const orderDetail = await mizzleMarket.GetOrderDetail(1);
        expect(orderDetail.buyer).to.equal(user1.address);
        expect(orderDetail.nftId).to.equal(nftId);
        expect(orderDetail.price).to.equal(price);
    });
});
