const { ethers, upgrades } = require("hardhat");

async function main() {
    let owner = "0xeA11B7D56668504800B7d0153ae650D20706466B";

    // Deploy the MizzleMarket contract as an upgradable proxy
    const DaoFactory = await ethers.getContractFactory("DAO");

    const dao = await upgrades.deployProxy(
        DaoFactory,
        [owner, '0x73a4722BdAcCfa2935a82728910933230014451A', 10], // Arguments for initialize function
        { initializer: "initialize" }
    );

    await dao.waitForDeployment();

    console.log("Dao deployed to:", await dao.getAddress());

}
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});

// Dao deployed to: 0xDc15f85F68dE30c7D5498a287C1F2054c18addB9