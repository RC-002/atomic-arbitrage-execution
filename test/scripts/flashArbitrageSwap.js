const { Contract } = require("ethers");
const { waffle } = require("hardhat");
const fs = require("fs");
const path = require("path");

require('dotenv').config({ path: __dirname + '/../.env' })

// Token addresses
const WETH_ADDRESS = '0x0165878A594ca255338adfa4d48449f69242Eb8F';
const artifacts = {
  Weth: require("../artifacts/contracts/Weth.sol/WrappedETH.json"),
};

const toEth = (wei) => ethers.utils.formatEther(wei);

async function main() {
  const provider = waffle.provider;
  const [owner, signer2] = await ethers.getSigners();

  const wethContract = new Contract(WETH_ADDRESS, artifacts.Weth.abi, provider);
  const contractAddress = process.env.FLASH_ARBITRAGE_EXECUTOR;

  // Validate contract address
  if (!ethers.utils.isAddress(contractAddress)) {
    console.error('Invalid contract address');
    return;
  }

  let wethBalance = await wethContract.connect(provider).balanceOf(contractAddress);

  

  console.log('-------------------- INITIAL BALANCES--------------------');
  console.log('WETH', toEth(wethBalance.toString()));


  // Step-1: Whitelist an EOA
  try {
    const whitelistFunctionSignature = "addToWhitelist(address)";
    const whitelistAddress = signer2.address;
    const whitelistFunctionSelector = ethers.utils.id(whitelistFunctionSignature).substring(0, 10);
    const encodedWhitelistAddress = ethers.utils.defaultAbiCoder.encode(["address"], [whitelistAddress]);
    const whitelistCallData = whitelistFunctionSelector + encodedWhitelistAddress.slice(2);

    const whitelistTx = await owner.sendTransaction({
      to: contractAddress,
      data: whitelistCallData,
      gasLimit: 3000000,
    });

    await whitelistTx.wait();
    console.log('-------------------- WHITELIST DONE--------------------');
  } catch (err) {
    console.error('Error in whitelisting:', err);
    return;
  }

  // Step-2: Process arbitrage requests from `arbitrage_encodings` directory
  console.log('\n-------------------- PROCESSING ARBITRAGE SWAPS--------------------');
  const encodingsDir = path.join(__dirname, "/../arbitrage_encodings");
  const files = fs.readdirSync(encodingsDir);

  for (let file of files) {
    let filePath = path.join(encodingsDir, file);
    file = file.replace(".json", "");

    if (!fs.lstatSync(filePath).isFile()) continue;

    // Read and parse the encoded calldata
    let fileContent = fs.readFileSync(filePath, "utf8");
    let { encoded_calldata: arbParameter } = JSON.parse(fileContent);

    try {
      console.log(`Processing: ${file}`);

      let arbFunctionSignature = "executeAtomicArbitrageSwap(bytes)";  

      // Encode the raw call data
      let arbFunctionSelector = ethers.utils.id(arbFunctionSignature).substring(0, 10);
      let encodedArbParameter = ethers.utils.defaultAbiCoder.encode(["bytes"], [arbParameter]);
      let arbCallData = arbFunctionSelector + encodedArbParameter.slice(2); // Combine selector and encoded parameter data


      let tx = await signer2.sendTransaction({
        to: contractAddress,
        data: arbCallData,
        gasLimit: 3000000,
      });
      await tx.wait();
      console.log(`Transaction confirmed for ${file}`);
    } catch (err) {
      console.error(`Error processing file ${file}:`, err);
    }

    // Log balances after all transactions
    wethBalance = await wethContract.connect(provider).balanceOf(contractAddress);
    console.log('\n-------------------- BALANCES AFTER SWAP -------------------');
    console.log('WETH: ', toEth(wethBalance.toString()));
  }
  
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
