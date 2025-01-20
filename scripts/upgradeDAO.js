const { ethers, upgrades } = require("hardhat");

async function main() {
    const proxyAddress = "0x52c48Fe2C4e2fa58B4937505cb30ba3ffc2383Db"; // Replace with the actual proxy address
    const DaoV2Factory = await ethers.getContractFactory("DAO");
    const upgradedDao = await upgrades.upgradeProxy(proxyAddress, DaoV2Factory);
    await upgradedDao.waitForDeployment();

    console.log("DAO upgraded to DAOv2 at address:", await upgradedDao.getAddress());
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
