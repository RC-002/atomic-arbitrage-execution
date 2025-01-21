// Load ethers from the `contracts` directory
const path = require("path");
const fs = require("fs");
const { createRequire } = require("module");

// Dynamically load ethers from the contracts package.json
const contractsRequire = createRequire(path.resolve(__dirname, "./../package.json"));


// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = contractsRequire("hardhat");

async function main() {
  // Load environment variables
  let WETH;
  let SAFE_EOA;
  if (hre.network.name === "localhost" || hre.network.name === "hardhat") {
    const [owner] = await ethers.getSigners();
    WETH = process.env.WETH_TEST_ADDRESS;
    SAFE_EOA = owner.address;
  } else {    
    WETH = process.env.WETH_ADDRESS;
    SAFE_EOA = process.env.SAFE_EOA;
  }

  if (!WETH || !SAFE_EOA) {
    throw new Error("Please set WETH_ADDRESS and SAFE_EOA in your environment variables.");
  }

  // Deploy the FlashArbitrageExecutor contract
  console.log("Deploying FlashArbitrageExecutor...");
  const flashArbitrageExecutor = await hre.ethers.deployContract("FlashArbitrageExecutor", [WETH, SAFE_EOA]);

  // Wait for the deployment to complete
  await flashArbitrageExecutor.waitForDeployment();

  const deployedAddress = flashArbitrageExecutor.target;

  console.log(`FlashArbitrageExecutor deployed at: ${deployedAddress}`);

  // Write the deployed address to the .env file only if in test mode
  if (hre.network.name === "localhost" || hre.network.name === "hardhat") {
    console.log("Test mode detected. Writing deployed address to .env file...");

    const envPath = path.resolve(__dirname, "../../test/.env");
    const envVar = `FLASH_ARBITRAGE_EXECUTOR=${deployedAddress}`;
    let envContent = "";

    if (fs.existsSync(envPath)) {
      // Load existing .env content
      envContent = fs.readFileSync(envPath, "utf-8");

      // Check if the variable already exists, replace it if so
      const regex = /^FLASH_ARBITRAGE_EXECUTOR=.*/gm;
      if (regex.test(envContent)) {
        envContent = envContent.replace(regex, envVar);
      } else {
        envContent += `\n${envVar}`;
      }
    } else {
      // Create a new .env file
      envContent = envVar;
    }

    // Write updated content back to the .env file
    fs.writeFileSync(envPath, envContent);

    console.log(`Deployed address written to .env file: ${envVar}`);
  }

}


// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
