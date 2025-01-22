
# Understanding and running the Project

## Deploying the Contract

### 1. Understanding the Contract
Before deploying the contract, it's essential to understand the following:
1. **SAFE EOA**: This is the primary account that holds administrative privileges.
2. **Whitelisting**: Only the SAFE EOA can whitelist other EOAs (Externally Owned Accounts) to execute swaps.
3. **Swapping**: Once whitelisted, an EOA can call the `executeAtomicArbitrageSwap` method to perform arbitrage swaps.
4. **Gas Costs**: The whitelisted EOA must have ETH to pay for gas fees but does not need any WETH balance. The contract allows swaps with no starting capital!
5. **Assert arbitrage**: The contract asserts that the WETH profit is greater than or equals to the expected minimum output amount

---

### 2. Steps to Deploy
1. **Install Dependencies**:
   Ensure you have Hardhat and all npm dependencies installed.
   ```bash
   npm install
   ```

2. **Configure Environment Variables**:
   Create a `.env` file in the project root and include the following parameters:
   ```env
   # NODE RPC Configuration
   MAINNET_NODE_RPC_URL=<Your Mainnet Node RPC URL>
   MAINNET_PRIVATE_KEY=<Your Private Key>

   # Deployment Parameters
   WETH_ADDRESS=<WETH Token Address>
   SAFE_EOA=<Address for safe execution>
   ```

3. **Deploy the Contract**:
   Use the deployment script provided in the project to deploy the contract to the Ethereum mainnet.
   ```bash
   npx hardhat run scripts/deploy.js --network mainnet
   ```

   **Note**: To test locally, follow these steps:
   - in a new terminal within the ```src/``` directory, run the hardhat node
   ```bash
   npx hardhat node --hostname localhost
   ```
   - Then deploy the contract in a new terminal
   ```bash
   npx hardhat run scripts/deploy.js --network localhost
   ```

---

### 3. Whitelisting an EOA
1. **Call the `addToWhitelist` Method**:
   Use the SAFE EOA to call the `addToWhitelist` method of the deployed contract.

2. **Provide the Address**:
   Pass the address of the EOA to be whitelisted as a parameter to the method.

### Example Code for Whitelisting
```javascript
const ethers = require("ethers");

// Parameters
const contractAddress = "<Deployed Contract Address>";
const eoaToWhitelist = "<EOA to Whitelist>";

// ABI and Provider
const contractAbi = [/* ABI of the contract */];
const provider = new ethers.providers.JsonRpcProvider(process.env.MAINNET_NODE_RPC_URL);
const wallet = new ethers.Wallet(process.env.MAINNET_PRIVATE_KEY, provider);

// Contract Instance
const contract = new ethers.Contract(contractAddress, contractAbi, wallet);

async function whitelistEOA() {
    try {
        const tx = await contract.addToWhitelist(eoaToWhitelist);
        console.log("Whitelisting Transaction Sent:", tx.hash);
        await tx.wait();
        console.log("EOA Successfully Whitelisted:", eoaToWhitelist);
    } catch (err) {
        console.error("Error Whitelisting EOA:", err);
    }
}

whitelistEOA();
```

### Notes
- Ensure the SAFE EOA has sufficient ETH for transaction fees.
- Only the whitelisted EOA can execute swaps after being authorized.
- Confirm that all parameters in the `.env` file are correctly set before deployment.

---

### 4. In-Depth Flow of the Contract

This section explains how the contract processes an arbitrage request step-by-step:

#### **1. Whitelisting Check**
- The contract begins by verifying if the sender of the transaction is whitelisted.
- If the sender is not whitelisted, the request is reverted immediately.

#### **2. Record Initial WETH Balance**
- If the sender is whitelisted, the contract notes the initial WETH balance of the contract, denoted as `balanceBeforeArbitrageSwaps`.

#### **3. Decode Arbitrage Request Parameters**
- The calldata is decoded to extract:
  - `amountIn`: The initial input amount for the arbitrage.
  - `minIncreaseInWeth`: The minimum acceptable profit in WETH for the arbitrage to proceed.
  - `firstHop`: The starting pool for the arbitrage sequence.
- **Key Detail:** The contract processes the swaps in reverse order, meaning the swap method of the last pool in the arbitrage sequence is called first.

#### **4. Processing Each Pool in the Arbitrage Sequence**
For each pool in the arbitrage request, the following steps are executed based on the type of pool:

##### **4.1 If the Pool is a Uniswap V3 Pool**
- Call the `swap` method of the Uniswap V3 pool.
- The pool transfers the `amountOut` in `tokenOut` to the contract and triggers the callback `uniswapV3SwapCallback` with:
  - `amountIn`
  - `amountOut`
  - The calldata provided in the request.
- Inside the callback:
  - Decode the current hop.
  - Verify that `msg.sender` matches the pool address to prevent spoofing.
- Remove the current hop from the calldata by slicing 21 bytes.
- If there is a next hop, call the `swap` method of the next pool.
- If this is the last pool in the sequence, pay the `amountIn` in `tokenIn` owed to the pool.

##### **4.2 If the Pool is a Uniswap V2 Pool**
- Call the `swap` method of the Uniswap V2 pool.
- The pool transfers the `amountOut` in `tokenOut` to the contract and triggers the callback `uniswapV2Call` with:
  - `amountOut`
  - The calldata provided in the request.
- Inside the callback:
  - Decode the current hop.
  - Verify that `msg.sender` matches the pool address to ensure authenticity.
- Remove the current hop from the calldata by slicing 21 bytes.
- Calculate the `amountIn` owed to the pool:
  - Fetch the pool reserves.
  - Use the Uniswap V2 library's `getAmountIn` function to compute the required `amountIn` based on the reserves and the already transferred `amountOut`.
  - **Note:** The reserves are updated after the swap, ensuring the correct `amountIn`.
- If there is a next hop, call the `swap` method of the next pool.
- If this is the last pool, pay the `amountIn` owed to the pool.

##### **Important Note:**
- The next pool is always called in the callback of the current pool.
- Only in the final pool’s callback does the contract start settling the owed amounts.
- This ensures that the required `amountIn` for each pool is always available during execution.
- The callback of the first pool is returned last, completing the entire sequence.

#### **5. Final Balance Validation**
- After all swaps are completed, the contract computes its final WETH balance (`balanceAfterArbitrageSwaps`).
- It verifies that the profit (`balanceAfterArbitrageSwaps - balanceBeforeArbitrageSwaps`) exceeds the `minIncreaseInWeth` specified in the request.
- If this condition is not met, the transaction reverts to prevent unprofitable or erroneous arbitrage execution.

---
 

---

## Off-Chain Component - The RUST Code

### 1. Understanding the Code
The arbitrage request, written in a human-readable JSON format, needs to be encoded into bytecode to be processed by the `FlashArbitrageExecutor` smart contract. This encoding is handled by the Rust program, which takes the JSON input and outputs the encoded calldata ready for deployment.

---

### 2. Dependencies
Ensure you have Rust installed and the following dependencies added to your `Cargo.toml` file:

```toml
[dependencies]
byteorder = "1.5.0"
hex = "0.4.3"
serde = { version = "1.0.217", features = ["derive"] }
serde_json = "1.0.137"
```

---

### 3. Using the code

#### 3.1 Preparing the Requests
1. Navigate to the /rust directory in your project.
2. Inside the arbitrage_requests folder, create a new JSON file representing your arbitrage request.
    - Use "mainnet" as the chain value for production requests.
    - Use "localhost" as the chain value for local testing.
3. Populate the JSON file with the details of your arbitrage request. For example:
```json
{
  "chain": "mainnet",
  "request": [
                {
                "pool_type": "uniswap_v2",
                "pool_address": "0xB4e16d0168e52d35CaCD2c6185b44281Ec28C9Dc",
                "amount_in": "1000000000",
                "amount_out": "3500000000",
                "token_in": "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",
                "token_out": "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"
                },
                {
                "pool_type": "uniswap_v3",
                "pool_address": "0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640",
                "amount_in": "3500000000",
                "amount_out": "1001000000000000000",
                "token_in": "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
                "token_out": "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"
                }
              ]
}
```
4. Run the Rust program to process the requests:
```bash
cargo run -q
```
5. **Encoding rules**:
- 128-bits uint indicating the exact input amount of WETH for the first swap
- 128-bits uint indicating the expected minimum increase in WETH balance (gross profit from above)
- Remaining bits data to be passed when calling flash swap (see below)
    - 1-bit as the selector (0 for UniswapV2-like pool, 1 for UniswapV3-like pool)
    - 1-bit as the direction (0 for selling token0 of the pool, 1 for selling token1 of the pool)
    - 160-bits as the pool address to perform the swap against
    The data for multiple hops should be packed sequentially.

#### 3.2 Retrieving the Output Encodings
- If your request was for the mainnet, the encoded data will be saved in the ```arbitrage_encodings``` directory within ```/rust```.
- If your request was for local testing (chain value is "localhost"), the encoded data will appear in the ```test/arbitrage_encoding directory ``` located in the project’s root.
- The output file will have the same name as your input JSON file, containing the encoded calldata.
- An example of the output is:
```json
{"chain":"mainnet","encoded_calldata":"0x0000000000000000000000003b9aca0000000000000000000de44432108fb600c088e6a0c2ddd26feeb64f039a2c41296fcb3f564000b4e16d0168e52d35cacd2c6185b44281ec28c9dc"}
```

---

### 4. High-Level Overview of the Code Flow and Modules

This project encodes arbitrage requests into calldata for blockchain execution. It is designed in a modular way to keep the code structured, efficient, and easy to extend. Below is a concise explanation of each module:

##### 1. `main.rs` - Entry Point
- **Purpose:** Manages directory setup and initiates request processing.
- **Flow:**
  - Ensures `encodings_dir` and `test_encodings_dir` exist.
  - Calls `process_arbitrage_requests` from the `parser` module.


##### 2. `helpers/arbitrage_request.rs` - Struct Definition
- **Purpose:** Defines the `ArbitrageRequest` structure with fields:
  - `pool_type`, `pool_address`, `amount_in`, `amount_out`, `token_in`, `token_out`.


##### 3. `helpers/encoder.rs` - Encoding Logic
- **Purpose:** Encodes arbitrage requests into calldata.
- **Flow:**
  - Validates `amount_in` and `amount_out` and calculates WETH profit.
  - Encodes:
    - `amount_in` and profit as 128-bit hex.
    - Pool details (type, direction, address) in reverse order.
  - Returns a hex-encoded calldata string.


##### 4. `helpers/parser.rs` - File Processing
- **Purpose:** Processes input JSON files and writes encoded output.
- **Flow:**
  - Reads requests from `requests_dir` and deserializes JSON.
  - Encodes requests using `encoder::encode_arbitrage_request`.
  - Writes output JSON with chain and calldata to the appropriate directory.
