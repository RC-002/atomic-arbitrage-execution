async function main() {
  const [owner, signer2] = await ethers.getSigners();

  WrappedETH = await ethers.getContractFactory('WrappedETH', owner);
  weth = await WrappedETH.deploy();

  Usdc = await ethers.getContractFactory('UsdCoin', owner);
  usdc = await Usdc.deploy();

  await weth.connect(owner).mint(
    owner.address,
    ethers.utils.parseEther('100000')
  )
  await usdc.connect(owner).mint(
    owner.address,
    ethers.utils.parseEther('100000')
  )

  console.log('WETH_ADDRESS=', `'${weth.address}'`)
  console.log('USDC_ADDRESS=', `'${usdc.address}'`)
}

/*
npx hardhat run --network localhost scripts/deployTokens.js
*/


main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });