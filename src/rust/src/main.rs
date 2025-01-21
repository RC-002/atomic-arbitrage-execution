use std::fs;
use serde_json;

mod helpers;
use helpers::arbitrage_request::ArbitrageRequest;
use helpers::encoder;

fn main() {
    let file_path = "arbitrage_request.json";
    let data = fs::read_to_string(file_path).expect("Failed to read file");

    // Deserialize the JSON into a vector of requests
    let requests: Vec<ArbitrageRequest> =
        serde_json::from_str(&data).expect("Error parsing JSON");

    // Encode the arbitrage request into a string
    match encoder::encode_arbitrage_request(requests) {
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
