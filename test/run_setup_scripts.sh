#!/bin/bash

# Function to run a command and print output sequentially
run_command() {
  echo "Running: $1"
  eval $1
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
)

# Execute the commands sequentially
for cmd in "${commands[@]}"; do
  run_command "$cmd"
done

# Change directory to src and execute the additional command
echo "Changing directory to ./../src"
cd ./../src || { echo "Failed to change directory to ./../src"; exit 1; }
run_command "npx hardhat run --network localhost scripts/deploy.js"

echo "All commands executed successfully!"
