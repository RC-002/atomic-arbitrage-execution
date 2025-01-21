#!/bin/bash

# Function to run a command and print output sequentially
run_command() {
  echo "Running: $1"
  $1
  if [ $? -ne 0 ]; then
    echo "Command failed: $1"
    exit 1
  fi
  echo "-----------------------------------------"
}

# List of commands to execute
commands=(
  "npx hardhat run --network localhost scripts/deployContracts.js"
  "npx hardhat run --network localhost scripts/deployTokens.js"
  "npx hardhat run --network localhost scripts/deployPools.js"
  "npx hardhat run --network localhost scripts/addLiquidity.js"
  "npx hardhat run --network localhost scripts/checkLiquidity.js"
  "npx hardhat run --network localhost scripts/flashArbitrageSwap.js"
)

# Iterate over commands and execute them sequentially
for cmd in "${commands[@]}"; do
  run_command "$cmd"
done

echo "All commands executed successfully!"
