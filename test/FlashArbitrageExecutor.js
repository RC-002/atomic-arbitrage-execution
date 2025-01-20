const { loadFixture } = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { expect } = require("chai");

describe("FlashArbitrageExecutor", function () {

  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.

  async function deployConractAndSetVariables() {
    const WETH = '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2';

    // Contracts are deployed using the first signer/account by default
    const [owner, _] = await ethers.getSigners();

    const FlashArbitrageExecutor = await ethers.getContractFactory("FlashArbitrageExecutor");
    const flashArbitrageExecutor = await FlashArbitrageExecutor.deploy(WETH, owner);

    return { flashArbitrageExecutor, owner };
  }

  describe("Deployment", function () {

    it("Should be able to whitelist an address", async function () {

      const [_, signer1] = await ethers.getSigners();
      const { flashArbitrageExecutor, owner } = await loadFixture(deployConractAndSetVariables);

      expect(await flashArbitrageExecutor.addToWhitelist(signer1))
      .to.emit(flashArbitrageExecutor, "Whitelisted")
      .withArgs(signer1, true);
    });
  });
});
