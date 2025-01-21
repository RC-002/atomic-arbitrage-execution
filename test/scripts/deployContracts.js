

const { Contract, ContractFactory, utils, BigNumber } = require("ethers")
const USDT9 = require("../USDT.json")

const artifacts = {
  UniswapV3Factory: require("@uniswap/v3-core/artifacts/contracts/UniswapV3Factory.sol/UniswapV3Factory.json"),
  SwapRouter: require("@uniswap/v3-periphery/artifacts/contracts/SwapRouter.sol/SwapRouter.json"),
  NFTDescriptor: require("@uniswap/v3-periphery/artifacts/contracts/libraries/NFTDescriptor.sol/NFTDescriptor.json"),
  NonfungibleTokenPositionDescriptor: require("@uniswap/v3-periphery/artifacts/contracts/NonfungibleTokenPositionDescriptor.sol/NonfungibleTokenPositionDescriptor.json"),
  NonfungiblePositionManager: require("@uniswap/v3-periphery/artifacts/contracts/NonfungiblePositionManager.sol/NonfungiblePositionManager.json"),
  USDT9,
};

const linkLibraries = ({ bytecode, linkReferences }, libraries) => {
  Object.keys(linkReferences).forEach((fileName) => {
    Object.keys(linkReferences[fileName]).forEach((contractName) => {
      if (!libraries.hasOwnProperty(contractName)) {
        throw new Error(`Missing link library name ${contractName}`)
      }
      const address = utils
        .getAddress(libraries[contractName])
        .toLowerCase()
        .slice(2)
      linkReferences[fileName][contractName].forEach(
        ({ start, length }) => {
          const start2 = 2 + start * 2
          const length2 = length * 2
          bytecode = bytecode
            .slice(0, start2)
            .concat(address)
            .concat(bytecode.slice(start2 + length2, bytecode.length))
        }
      )
    })
  })
  return bytecode
}

async function main() {
  const [owner] = await ethers.getSigners();

  USDT = new ContractFactory(artifacts.USDT9.abi, artifacts.USDT9.bytecode, owner);
  USDT = await USDT.deploy();

  Factory = new ContractFactory(artifacts.UniswapV3Factory.abi, artifacts.UniswapV3Factory.bytecode, owner);
  factory = await Factory.deploy();

  SwapRouter = new ContractFactory(artifacts.SwapRouter.abi, artifacts.SwapRouter.bytecode, owner);
  swapRouter = await SwapRouter.deploy(factory.address, USDT.address);

  NFTDescriptor = new ContractFactory(artifacts.NFTDescriptor.abi, artifacts.NFTDescriptor.bytecode, owner);
  nftDescriptor = await NFTDescriptor.deploy();

  const linkedBytecode = linkLibraries(
    {
      bytecode: artifacts.NonfungibleTokenPositionDescriptor.bytecode,
      linkReferences: {
        "NFTDescriptor.sol": {
          NFTDescriptor: [
            {
              length: 20,
              start: 1261,
            },
          ],
        },
      },
    },
    {
      NFTDescriptor: nftDescriptor.address,
    }
  );

  NonfungibleTokenPositionDescriptor = new ContractFactory(artifacts.NonfungibleTokenPositionDescriptor.abi, linkedBytecode, owner);
  nonfungibleTokenPositionDescriptor = await NonfungibleTokenPositionDescriptor.deploy(USDT.address);

  NonfungiblePositionManager = new ContractFactory(artifacts.NonfungiblePositionManager.abi, artifacts.NonfungiblePositionManager.bytecode, owner);
  nonfungiblePositionManager = await NonfungiblePositionManager.deploy(factory.address, USDT.address, nonfungibleTokenPositionDescriptor.address);

  console.log('USDT_ADDRESS=', `'${USDT.address}'`)
  console.log('FACTORY_ADDRESS=', `'${factory.address}'`)
  console.log('SWAP_ROUTER_ADDRESS=', `'${swapRouter.address}'`)
  console.log('NFT_DESCRIPTOR_ADDRESS=', `'${nftDescriptor.address}'`)
  console.log('POSITION_DESCRIPTOR_ADDRESS=', `'${nonfungibleTokenPositionDescriptor.address}'`)
  console.log('POSITION_MANAGER_ADDRESS=', `'${nonfungiblePositionManager.address}'`)
}

/*
npx hardhat run --network localhost scripts/deployContracts.js
*/

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });