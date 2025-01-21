// parser.rs
use std::fs::{self, File};
use std::io::Write;
use serde_json::{self, Value};

use super::arbitrage_request::ArbitrageRequest;
use super::encoder;

pub fn process_arbitrage_requests(requests_dir: &str, encodings_dir: &str, test_encodings_dir: &str) {
    // Iterate over all files in the requests directory
    for entry in fs::read_dir(requests_dir).expect("Failed to read requests directory") {
        let entry = entry.expect("Failed to read directory entry");
        let path = entry.path();

        if path.is_file() {
            // Read and deserialize the JSON file
            let file_name = path.file_name().unwrap().to_str().unwrap();
            let data = fs::read_to_string(&path).expect("Failed to read file");
            let json: Value = serde_json::from_str(&data).expect("Failed to parse JSON");

             // Extract chain and requests
             let chain = json["chain"]
                .as_str()
                .expect("Missing or invalid chain field")
                .trim()
                .to_lowercase();
            let requests: Vec<ArbitrageRequest> = serde_json::from_value(
                json["request"].clone(),
            )
            .expect("Failed to parse requests");

            // Encode the arbitrage request
            match encoder::encode_arbitrage_request(requests) {
                Ok(encoded_data) => {
                    // Create the output JSON
                    let output = serde_json::json!({
                        "chain": chain,
                        "encoded_calldata": format!("0x{}", encoded_data),
                    });

                    // Determine the output path based on the chain
                    let output_path = if chain == "localhost" {
                        format!("{}/{}", test_encodings_dir, file_name)
                    } else {
                        format!("{}/{}", encodings_dir, file_name)
                    };

                    // Write the output JSON to the encodings directory
                    let mut file =
                        File::create(&output_path).expect("Failed to create output file");
                    file.write_all(output.to_string().as_bytes())
                        .expect("Failed to write to output file");
                    println!("Encoded and wrote: {}", output_path);
                }
                Err(e) => {
                    eprintln!("Error encoding file {}: {}", file_name, e);
                }
            }
        }
    }
}
