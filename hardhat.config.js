require("@nomicfoundation/hardhat-toolbox");
require("@nomicfoundation/hardhat-ignition-ethers");
require("dotenv").config();

module.exports = {
  defaultNetwork: "sepolia",
  //networks configuration for sepolia and bscTestnet networks
  networks: {
    sepolia: {
      url: `https://sepolia.infura.io/v3/${process.env.INFURA_API_KEY}`,
      accounts: process.env.OWNER_PRIVATE_KEY
        ? [process.env.OWNER_PRIVATE_KEY]
        : [],
    },
    bscTestnet: {
      url: `https://bsc-testnet.infura.io/v3/${process.env.INFURA_API_KEY}`,
      accounts: process.env.OWNER_PRIVATE_KEY
        ? [process.env.OWNER_PRIVATE_KEY]
        : [],
    },
  },
  //verify contract source code on etherscan with sourcify plugin
  sourcify:{
    enabled: true,
  },
  solidity: {
    version: "0.8.28",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  //verify contract on etherscan with hardhat-etherscan plugin
  etherscan: {
    apiKey: {
      bscTestnet: process.env.BSCSCAN_API_KEY,
    },
  },
};
