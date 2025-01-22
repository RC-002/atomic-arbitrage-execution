# Testing the Project

## 1. Understanding the Test
- This test evaluates the entire flow of the project.
- It leverages Hardhat's local node to simulate the Ethereum environment.
- Uniswap V3 pools are created with skewed price ratios between the tokens, creating an arbitrage opportunity to be tested.

## 2. Pre-requisites
1. Ensure Hardhat and Node dependencies are installed.
2. Start the Hardhat node by running:
   ```bash
   npx hardhat node
   ```
3. Deploy the contract on the local Hardhat network. Refer to the steps in the [``` /src/README.md``` file](https://github.com/RC-002/atomic-arbitrage-execution/blob/main/src/README.md).
4. Add a new request in the arbitrage_requests folder within the /rust directory.
    - Ensure the chain field in your JSON request is set to "localhost".
    - Run the Rust code to encode the request.
5. Verify that the encoded request appears in the test/arbitrage_encodings directory.



## 3. Running the test

1. **Setup**:
- Execute the ```run_setup_script.sh``` script to setup the necessary tokens, pools and also deploy our FlashArbitrage contract
```bash
./run_setup_script.sh
```

2. **Running the arbitrage test**
- Execute the ```run_arbitrage_script.sh``` script to run the test suite.
```bash
./run_arbitrage_script.sh
```

### 3.1 Sample Logs:
Below is an example of the logs you should expect during execution:

``` bash
Running: npx hardhat run --network localhost scripts/deployContracts.js
USDT_ADDRESS= '0x5FbDB2315678afecb367f032d93F642f64180aa3'
FACTORY_ADDRESS= '0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512'
SWAP_ROUTER_ADDRESS= '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0'
NFT_DESCRIPTOR_ADDRESS= '0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9'
POSITION_DESCRIPTOR_ADDRESS= '0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9'
POSITION_MANAGER_ADDRESS= '0x5FC8d32690cc91D4c39d9d3abcBD16989F875707'
-----------------------------------------
Running: npx hardhat run --network localhost scripts/deployTokens.js
WETH_ADDRESS= '0x0165878A594ca255338adfa4d48449f69242Eb8F'
USDC_ADDRESS= '0xa513E6E4b8f2a923D98304ec87F64353C4D5C853'
-----------------------------------------
Running: npx hardhat run --network localhost scripts/deployPools.js
WETH_USDC_500= '0x1FA8DDa81477A5b6FA1b2e149e93ed9C7928992F'
WETH_USDC_3000= '0x3B00F82071576B8489A6e3df223dcC0e937841d1'
WETH_USDC_10000= '0xb09EB46A30889ae3cE4AFa5d8ebD136B4f389B85'
-----------------------------------------
Running: npx hardhat run --network localhost scripts/addLiquidity.js
done
-----------------------------------------
Running: npx hardhat run --network localhost scripts/checkLiquidity.js
poolData500 {
  tickSpacing: 10,
  fee: 500,
  liquidity: '100000000000000000003',
  sqrtPriceX96: '79228162514264337593543950336',
  priceRatio: '1',
  tick: 0
}
poolData3000 {
  tickSpacing: 60,
  fee: 3000,
  liquidity: '100000000000000000000',
  sqrtPriceX96: '56022770974786139918731938227',
  priceRatio: '0.5',
  tick: -6932
}
poolData10000 {
  tickSpacing: 200,
  fee: 10000,
  liquidity: '100000000000000000000',
  sqrtPriceX96: '112045541949572279837463876454',
  priceRatio: '2',
  tick: 6931
}
-----------------------------------------
Running: npx hardhat run --network localhost scripts/flashArbitrageSwap.js
-------------------- INITIAL BALANCES--------------------
WETH 0.0
-------------------- WHITELIST DONE--------------------

-------------------- PROCESSING ARBITRAGE SWAPS--------------------
Processing: request1
Transaction confirmed for request1

-------------------- BALANCES AFTER SWAP -------------------
WETH:  0.0
-----------------------------------------
All commands executed successfully!
```

### 3.2 Key Highlights from the Logs
- **Contract Deployment**: Uniswap V3 Factory and other dependent contracts are created.
- **Token Contracts:** WETH and USDC token contracts are deployed.
- **Pool Creation**: Uniswap V3 pools are deployed with specified parameters.
- **Liquidity Addition**: Liquidity is added to the pools to create an arbitrage scenario.
- **Arbitrage Execution**: The arbitrage flash swap is executed successfully.


## 4. Close look at the arbitrage flash swap
- During the local deployment, the contract address is saved in the ```test/.env``` file for use during testing.
- The safe address is the Hardhat owner's contract.
- The signer (EOA) is whitelisted for making swaps.
- **Initial Balance Check**: The initial WETH balance of the signer is logged.
- **Whitelisting**: The signer is whitelisted by the safe address.
- **Executing** the Arbitrage:
    - The encoded request from the test/arbitrage_encodings directory is passed to the executeAtomicArbitrageSwap method.
    - The contract executes the flash swap, completing the arbitrage.
- **Final Balance Check**: After the swap, the signer's WETH balance increases, indicating a successful arbitrage.

*reference for the [tests](https://gist.github.com/BlockmanCodes/d0068cfc56ab67925dfd4b854ffea8fc)*