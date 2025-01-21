require("@nomiclabs/hardhat-waffle");

module.exports = {
  solidity: {
    compilers: [
      { version: "0.8.10" },
    ],
    settings: {
      optimizer: {
        enabled: true,
        runs: 5000,
        details: { yul: false },
      },
    }
  },
};