// main.rs
use std::path::Path;

mod helpers;
use helpers::parser::process_arbitrage_requests;

fn main() {
    let requests_dir = "arbitrage_requests"; // Input directory
    let encodings_dir = "arbitrage_encodings"; // Output directory

    // Ensure the encodings directory exists
    if !Path::new(encodings_dir).exists() {
        std::fs::create_dir(encodings_dir).expect("Failed to create encodings directory");
    }

    // Process arbitrage requests from the input directory
    process_arbitrage_requests(requests_dir, encodings_dir);
}
