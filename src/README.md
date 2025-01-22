
# Running the Project

## Deploying the Contract

### 1. Understanding the Contract
Before deploying the contract, it's essential to understand the following:
1. **SAFE EOA**: This is the primary account that holds administrative privileges.
2. **Whitelisting**: Only the SAFE EOA can whitelist other EOAs (Externally Owned Accounts) to execute swaps.
3. **Swapping**: Once whitelisted, an EOA can call the `executeAtomicArbitrageSwap` method to perform arbitrage swaps.
4. **Gas Costs**: The whitelisted EOA must have ETH to pay for gas fees but does not need any WETH balance. The contract allows swaps with no starting capital!

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



## Off-Chain Component - The RUST Code

### 1. Understanding the Code
The arbitrage request, written in a human-readable JSON format, needs to be encoded into bytecode to be processed by the `FlashArbitrageExecutor` smart contract. This encoding is handled by the Rust program, which takes the JSON input and outputs the encoded calldata ready for deployment.

### 2. Dependencies
Ensure you have Rust installed and the following dependencies added to your `Cargo.toml` file:

```toml
[dependencies]
byteorder = "1.5.0"
hex = "0.4.3"
serde = { version = "1.0.217", features = ["derive"] }
serde_json = "1.0.137"
```

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

#### 3.2 Retrieving the Output Encodings
- If your request was for the mainnet, the encoded data will be saved in the ```arbitrage_encodings``` directory within ```/rust```.
- If your request was for local testing (chain value is "localhost"), the encoded data will appear in the ```test/arbitrage_encoding directory ``` located in the project’s root.
- The output file will have the same name as your input JSON file, containing the encoded calldata.
- An example of the output is:
```json
{"chain":"mainnet","encoded_calldata":"0x0000000000000000000000003b9aca0000000000000000000de44432108fb600c088e6a0c2ddd26feeb64f039a2c41296fcb3f564000b4e16d0168e52d35cacd2c6185b44281ec28c9dc"}
```