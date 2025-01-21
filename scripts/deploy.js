// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");

async function main() {
  // Load environment variables
  const WETH = process.env.WETH_ADDRESS;
  const SAFE_EOA = process.env.SAFE_EOA;

  console.log(process.env);

  if (!WETH || !SAFE_EOA) {
    throw new Error("Please set WETH_ADDRESS and SAFE_EOA in your environment variables.");
  }

  // Deploy the FlashArbitrageExecutor contract
  console.log("Deploying FlashArbitrageExecutor...");
  const flashArbitrageExecutor = await hre.ethers.deployContract("FlashArbitrageExecutor", [WETH, SAFE_EOA]);

  // Wait for the deployment to complete
  await flashArbitrageExecutor.waitForDeployment();

  console.log(
    `FlashArbitrageExecutor deployed at: ${flashArbitrageExecutor.target}`
  );
}


// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
