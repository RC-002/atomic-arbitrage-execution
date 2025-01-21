use serde::Deserialize;
use std::fs;
use hex;

#[derive(Deserialize, Debug)]
struct ArbitrageRequest {
    pool_type: String,
    pool_address: String,
    amount_in: String,
    amount_out: String,
    token_in: String,
    token_out: String,
}

fn encode_arbitrage_request(requests: Vec<ArbitrageRequest>) -> Result<String, String> {
    let mut result = String::new();

    // Parse input and output amounts
    let amount_in = requests[0]
        .amount_in
        .parse::<u128>()
        .map_err(|_| String::from("Invalid amount_in"))?;
    let amount_out = requests
        .last()
        .expect("Empty requests")
        .amount_out
        .parse::<u128>()
        .map_err(|_| String::from("Invalid amount_out"))?;

    // Calculate WETH Profit
    if amount_in > amount_out {
        return Err(String::from("Arbitrage request does not generate a profit"));
    }
    let weth_profit = amount_out - amount_in;

    // Encode initial 128-bit values as hex and append to the result
    result.push_str(&hex::encode(&amount_in.to_be_bytes()));
    result.push_str(&hex::encode(&weth_profit.to_be_bytes()));

    // Encode each hop in reverse order
    for request in requests.iter().rev() {
        let is_v3 = (request.pool_type == "uniswap_v3") as u8;
        let direction = (request.token_in < request.token_out) as u8;
        let pool_address = hex::decode(request.pool_address.trim_start_matches("0x"))
            .map_err(|_| String::from("Invalid pool address"))?;

        // Pack the first byte with the selector and direction bits
        result.push_str(&hex::encode(vec![(is_v3 << 7) | (direction << 6)]));

        // Append the pool address (20 bytes)
        result.push_str(&hex::encode(pool_address));
    }

    Ok(result)
}

fn main() {
    let file_path = "arbitrage_request.json";
    let data = fs::read_to_string(file_path).expect("Failed to read file");

    // Deserialize the JSON into a vector of requests
    let requests: Vec<ArbitrageRequest> =
        serde_json::from_str(&data).expect("Error parsing JSON");

    // Encode the arbitrage request into a string
    match encode_arbitrage_request(requests) {
        Ok(encoded_data) => {
            // Print the encoded data in hex format (as a string)
            println!("Encoded Data (in Hex): 0x{}", encoded_data);
        }
        Err(e) => {
            // Handle error if the encoding fails
            eprintln!("Error encoding arbitrage request: {}", e);
        }
    }
}
