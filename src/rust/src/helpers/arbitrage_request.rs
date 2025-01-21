use serde::Deserialize;

#[derive(Deserialize, Debug)]
pub struct ArbitrageRequest {
    pub pool_type: String,
    pub pool_address: String,
    pub amount_in: String,
    pub amount_out: String,
    pub token_in: String,
    pub token_out: String,
}
