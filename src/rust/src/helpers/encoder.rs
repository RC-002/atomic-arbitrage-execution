use super::arbitrage_request::ArbitrageRequest;
use hex;

pub fn encode_arbitrage_request(requests: Vec<ArbitrageRequest>) -> Result<String, String> {
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
