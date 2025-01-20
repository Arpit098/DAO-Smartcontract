const { ethers, upgrades } = require("hardhat");

async function main() {
    const proxyAddress = "0x73a4722BdAcCfa2935a82728910933230014451A"; // Replace with the actual proxy address
    const MizzleV2Factory = await ethers.getContractFactory("MizzleMarket");
    const upgradedMizzle = await upgrades.upgradeProxy(proxyAddress, MizzleV2Factory);
    await upgradedMizzle.waitForDeployment();

    console.log("Mizzle upgraded to Mizzlev2 at address:", await upgradedMizzle.getAddress());
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
