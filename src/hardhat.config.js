// Load ethers from the `src` directory
const path = require("path");
const { createRequire } = require("module");

// Dynamically load ethers from the contracts package.json
const contractsRequire = createRequire(path.resolve(__dirname, "./package.json"));

contractsRequire("@nomicfoundation/hardhat-toolbox");
contractsRequire('dotenv').config({ path: __dirname + '/.env' })

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.24",
  networks: {
    hardhat: {
    },
    mainnet: {
      url: process.env.MAINNET_NODE_RPC_URL || "",
      accounts: process.env.MAINNET_PRIVATE_KEY ? [process.env.MAINNET_PRIVATE_KEY] : [],
    },
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY || "",
  },

    // Add other networks for deployment if needed
};