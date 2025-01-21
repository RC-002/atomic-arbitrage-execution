// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

library ArbitrageRequestDecoder {

    // Struct to represent each hop in the arbitrage path
    struct Hop {
        bool isV3;          // True for Uniswap V3, false for Uniswap V2
        bool direction;     // True if selling token1, false if selling token0
        address poolAddress; // Address of the Uniswap V2 or V3 pool
    }


    function decodeU128data(bytes calldata data)
        internal
        pure
        returns (uint256 u128data) 
    {
        // Decode amountIn
        assembly {
            u128data := calldataload(data.offset)
            u128data := and(shr(128, u128data), 0xffffffffffffffffffffffffffffffff)
        }
    }

    /// @dev Decodes the input amount, minimum WETH balance increase, and first hop from the encoded data
    /// @param data The encoded data of the arbitrage request
    /// @return amountIn The input amount for the first swap
    /// @return minIncreaseInWeth The minimum WETH balance increase expected
    /// @return hop The decoded first hop data (pool type, direction, address)
    /// @return arbitrageNextHopCalldata The data for the nextHops
    function decodeFirstHop(bytes calldata data)
        internal
        pure
        returns (uint256 amountIn, uint256 minIncreaseInWeth, Hop memory hop, bytes memory arbitrageNextHopCalldata)
    {
        require(data.length >= 32, "Invalid data length");

        amountIn = decodeU128data(data);

        // Slice out the used part (16 bytes for amountIn)
        bytes calldata slicedData = data[16:];

        // Decode minIncreaseInWeth
        minIncreaseInWeth = decodeU128data(slicedData);

        // Slice out the used part (16 bytes for minIncreaseInWeth)
        slicedData = slicedData[16:];

        // Decode the first hop from the remaining data
        hop = decodeHop(slicedData);

        // Slice out and concatenate data[:16] and data[32:]
        arbitrageNextHopCalldata = new bytes(data.length - 16);
        assembly {
            let offset32 := add(data.offset, 32) // Skip the first 32 bytes
            let offset16 := data.offset // Start at the beginning (0 bytes)

            let length32 := sub(data.length, 32) // Length of data[32:]
            let length16 := 16 // Length of data[:16]

            // Allocate memory for the result
            let result := add(arbitrageNextHopCalldata, 32)
            let resultLength := add(length32, length16)

            // Copy data[32:] into result
            for { let i := 0 } lt(i, length32) { i := add(i, 32) } {
                mstore(add(result, i), calldataload(add(offset32, i)))
            }

            // Copy data[:16] into result after data[32:]
            for { let i := 0 } lt(i, length16) { i := add(i, 32) } {
                mstore(add(result, add(length32, i)), calldataload(add(offset16, i)))
            }

            // Update the free memory pointer
            mstore(0x40, add(result, add(resultLength, 32)))
        }
    }

    /// @dev Decodes a hop from the encoded data
    /// @param data The encoded data of the arbitrage request
    /// @return hop The decoded hop struct
    function decodeHop(bytes calldata data)
        internal
        pure
        returns (Hop memory)
    {
        bool isV3 = (uint8(data[0]) & 0x80) != 0; // Extract the Uniswap version (V2 or V3)
        bool direction = (uint8(data[0]) & 0x40) != 0; // Extract the direction (selling token0 or token1)

        // Move to the next 160 bits (pool address)
        address poolAddress;
        assembly {
            poolAddress := shr(96, calldataload(add(data.offset, 1))) // Extract pool address (160 bits)
        }

        return Hop(isV3, direction, poolAddress);
    }

    /// @dev Processes the next hop in the sequence
    /// @param data The encoded data of the arbitrage request
    /// @return hasMoreHops True if there are more hops to process, false otherwise
    function hasNextHop(bytes calldata data)
        internal
        pure
        returns (bool hasMoreHops)
    {
        return data.length >= 21; // Each hop is 21 bytes
    }
}
