# Sample Hardhat Project

This project demonstrates a basic Hardhat use case. It comes with a sample contract, a test for that contract, and a Hardhat Ignition module that deploys that contract.

Need to Install

```
npm install --save-dev @nomicfoundation/hardhat-ignition-ethers
npm install dotenv
```

Try running some of the following tasks:

```shell
npx hardhat help
npx hardhat test

npx hardhat node
npx hardhat ignition deploy ./ignition/modules/Token.js
```

# Commnds for deployment

<!--  -->

npx hardhat compile
npx hardhat node

<!-- sepolia deployment and verify -->

npx hardhat ignition deploy ./ignition/modules/Token --network sepolia --verify

<!-- bsc deployment and verify  -->

npx hardhat ignition deploy .\ignition\modules\Token --network bscTestnet --verify
