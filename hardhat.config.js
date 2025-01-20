require("@nomicfoundation/hardhat-toolbox");
require('@openzeppelin/hardhat-upgrades');

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.20",
  settings: {
    optimizer: {
      enabled: true,
      runs: 200,
    },
  },
  networks: { 
    binance: {
      url: 'https://bsc-testnet-dataseed.bnbchain.org',
      gasPrice: 30e9,
      chainId: 97,
      accounts: ["0x2b2be6c710a2a0b72da5066033b8a63e37d5de1c40231182a2e0fb9f74c7ca95"]
    },  
    amoy:{
      url: 'https://polygon-amoy.drpc.org',
      gasPrice: 30e9,
      gas: 30e6,
      chainId: 80002,
      accounts: ["2b2be6c710a2a0b72da5066033b8a63e37d5de1c40231182a2e0fb9f74c7ca95"]
    }
  },
  etherscan:{
    // apiKey:{
    //   bscTestnet:"NKRXUG3DVI7B4ESKUG15G6H6A9CMAI6NS9"
    // }
    apiKey:{
      polygonAmoy: 'AE5ZP8KQN1TN1A7CEY42I4XBWBMYYY568E'
    }
  } 
};
