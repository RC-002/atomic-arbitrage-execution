const { Contract } = require("ethers");
const { waffle } = require("hardhat");

require('dotenv').config({ path: __dirname + '../.env' })

// Token addresses
const WETH_ADDRESS = '0x0165878A594ca255338adfa4d48449f69242Eb8F';
const USDC_ADDRESS = '0xa513E6E4b8f2a923D98304ec87F64353C4D5C853';

const USDT9 = require("../USDT.json");
const artifacts = {
  UniswapV3Factory: require("@uniswap/v3-core/artifacts/contracts/UniswapV3Factory.sol/UniswapV3Factory.json"),
  SwapRouter: require("@uniswap/v3-periphery/artifacts/contracts/SwapRouter.sol/SwapRouter.json"),
  NFTDescriptor: require("@uniswap/v3-periphery/artifacts/contracts/libraries/NFTDescriptor.sol/NFTDescriptor.json"),
  NonfungibleTokenPositionDescriptor: require("@uniswap/v3-periphery/artifacts/contracts/NonfungibleTokenPositionDescriptor.sol/NonfungibleTokenPositionDescriptor.json"),
  NonfungiblePositionManager: require("@uniswap/v3-periphery/artifacts/contracts/NonfungiblePositionManager.sol/NonfungiblePositionManager.json"),
  Weth: require("../artifacts/contracts/Weth.sol/WrappedETH.json"),
  Usdc: require("../artifacts/contracts/UsdCoin.sol/UsdCoin.json"),
  USDT9,
};

const toEth = (wei) => ethers.utils.formatEther(wei);

async function main() {

  const path = require("path");
  require('dotenv').config({ path: __dirname + '/../.env' })

  const provider = waffle.provider;
  const [owner, signer2] = await ethers.getSigners();

  const wethContract = new Contract(WETH_ADDRESS, artifacts.Weth.abi, provider);
  const usdcContract = new Contract(USDC_ADDRESS, artifacts.Usdc.abi, provider);

  const contractAddress = process.env.FLASH_ARBITRAGE_EXECUTOR;

  let wethBalance = await wethContract.connect(provider).balanceOf(contractAddress);
  let usdcBalance = await usdcContract.connect(provider).balanceOf(contractAddress);

  

  console.log('-------------------- BEFORE');
  console.log('wethBalance', toEth(wethBalance.toString()));
  console.log('usdcBalance', toEth(usdcBalance.toString()));
  console.log('--------------------');

  

  if (!ethers.utils.isAddress(contractAddress)) {
    console.error('Invalid contract address');
    return;
  }

    // Step-1: Whitelist an EOA
    const whitelistFunctionSignature = "addToWhitelist(address)";
    const whitelistAddress = signer2.address;

    // Encode the raw call data
    const whitelistFunctionSelector = ethers.utils.id(whitelistFunctionSignature).substring(0, 10);
    const encodedWhitelistAddress = ethers.utils.defaultAbiCoder.encode(["address"], [whitelistAddress]);
    const whitelistCallData = whitelistFunctionSelector + encodedWhitelistAddress.slice(2); // Combine selector and encoded parameter data


  // Perform the raw call
  try {
    const whitelistTx = await owner.sendTransaction({
      to: contractAddress,
      data: whitelistCallData,
      gasLimit: 3000000, // Adjust as needed
    });

    await whitelistTx.wait();
    console.log('-------------------- WHITELIST DONE');
  } catch (err) {
    console.error('\n------------------------\nError in whitelisting:', err);
    return;
  }

  // Step-2: Send Arbitrage Request
    const arbFunctionSignature = "executeAtomicArbitrageSwap(bytes)";
    const arbParameter = "0x000000000000000000000000000f4240000000000000000000000000000003e8803b00f82071576b8489a6e3df223dcc0e937841d1c01fa8dda81477a5b6fa1b2e149e93ed9c7928992f";

    // Encode the raw call data
    const arbFunctionSelector = ethers.utils.id(arbFunctionSignature).substring(0, 10);
    const encodedArbParameter = ethers.utils.defaultAbiCoder.encode(["bytes"], [arbParameter]);
    const arbCallData = arbFunctionSelector + encodedArbParameter.slice(2); // Combine selector and encoded parameter data

// Perform the raw call
try {
  const tx = await signer2.sendTransaction({
    to: contractAddress,
    data: arbCallData,
    gasLimit: 3000000, // Adjust as needed
  });


    console.log('-------------------- ARBITRAGE FLASH SWAP TXN SENT');
    await tx.wait();
    console.log(`Transaction confirmed.`);
  } catch (err) {
    console.error('\n------------------------\nError in arbitrage transaction:', err);
    return;
  }

  // Log balances after transaction
  wethBalance = await wethContract.connect(provider).balanceOf(contractAddress);
  usdcBalance = await usdcContract.connect(provider).balanceOf(contractAddress);
  console.log('\n-------------------- AFTER');
  console.log('wethBalance', toEth(wethBalance.toString()));
  console.log('usdcBalance', toEth(usdcBalance.toString()));
  console.log('--------------------');
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
