const { ethers, upgrades } = require("hardhat");
    

async function main() {
    const owner = "0xeA11B7D56668504800B7d0153ae650D20706466B";
    const collector = "0xeA11B7D56668504800B7d0153ae650D20706466B";
    const keeper = "0xeA11B7D56668504800B7d0153ae650D20706466B";

    // Deploy Mock ERC20 Tokens
    const Token = await ethers.getContractFactory("Token");

    const mizzlToken = await Token.deploy("Mizzle Token", "MIZZL");
    await mizzlToken.deployed();

    const usdt = await Token.deploy("USDT", "USDT");
    await usdt.deployed();

    // Deploy the MizzleMarket contract as an upgradable proxy
    const MizzleMarketFactory = await ethers.getContractFactory("MizzleMarket");

    const mizzleMarket = await upgrades.deployProxy(
        MizzleMarketFactory,
        [owner, collector, "0x88F011b645Aa2f045e75cB9ba5ab96f49CC4eC43", "0xB86d7B6D0590f47007FaaC694B2bb15C2ca3BD90", keeper, 10],
        { initializer: "initialize" }
    );

    await mizzleMarket.deployed();

    console.log("MizzleMarket deployed to:", mizzleMarket.address);
    console.log("MizzleToken deployed to:", mizzlToken.address);
   
    await usdt.waitForDeployment();

  
    // Deploy the MizzleMarket contract as an upgradable proxy
    // const MizzleMarketFactory = await ethers.getContractFactory("MizzleMarket");

    // const mizzleMarket = await upgrades.deployProxy(
    //     MizzleMarketFactory,
    //     [owner, collector,"0x88F011b645Aa2f045e75cB9ba5ab96f49CC4eC43", "0xB86d7B6D0590f47007FaaC694B2bb15C2ca3BD90", keeper, 10], // Arguments for initialize function
    //     { initializer: "initialize" } // Specify the name of the initializer function
    // );

    // await mizzleMarket.waitForDeployment();

    // console.log("MizzleMarket deployed to:", await mizzleMarket.getAddress());
    // console.log("MizzleToken deployed to:", await mizzlToken.getAddress());
    console.log("Token deployed to:", await usdt.getAddress());
//     console.log("DAOToken deployed to:", await daoToken.getAddress());

}
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
