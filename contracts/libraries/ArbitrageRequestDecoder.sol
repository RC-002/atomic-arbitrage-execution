// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

library ArbitrageRequestDecoder {    
    // Struct to represent each hop in the arbitrage path
    struct Hop {
        bool isV3; // true for Uniswap V3, false for V2
        bool direction; // true if selling token1, false if selling token0
        address poolAddress; // Address of the pool
    }

    /// @dev Decodes the input amount, minimum WETH balance increase, and first hop from the encoded data
    /// @param data The encoded data of the arbitrage request
    /// @return amountIn The input amount for the first swap
    /// @return minIncreaseInWeth The minimum WETH balance increase expected
    /// @return hop The decoded first hop data (pool type, direction, address)
    function decodeFirstHop(bytes calldata data)
        internal
        pure
        returns (uint256 amountIn, uint256 minIncreaseInWeth, Hop memory hop)
    {
        require(data.length >= 32, "Invalid data length");
        
        assembly {
            // Load the first 32 bytes (256 bits)
            let inputData := calldataload(data.offset)

            // Extract only the upper 128 bits (16 bytes) for amountIn
            amountIn := and(shr(128, inputData), 0xffffffffffffffffffffffffffffffff)
            
            // Extract the next 32 bytes (256 bits)
            inputData := calldataload(add(data.offset, 16))

            // Extract only the upper 128 bits (16 bytes) for minIncreaseInWeth
            minIncreaseInWeth := and(shr(128, inputData), 0xffffffffffffffffffffffffffffffff)
        }

        // Decode the first hop after 32 bytes (amountIn + minIncreaseInWeth)
        hop = decodeHop(data, 32);
    }

    /// @dev Decodes a hop from the encoded data at a given offset
    /// @param data The encoded data of the arbitrage request
    /// @param offset The offset at which the hop data starts
    /// @return hop The decoded hop struct
    function decodeHop(bytes calldata data, uint256 offset)
        internal
        pure
        returns (Hop memory)
    {
        bool isV3 = (uint8(data[offset]) & 0x80) != 0; // Extract the Uniswap version (V2 or V3)
        bool direction = (uint8(data[offset]) & 0x40) != 0; // Extract the direction (selling token0 or token1)

        // Move to the next 160 bits (pool address)
        address poolAddress;
        assembly {
            poolAddress := shr(96, calldataload(add(data.offset, add(offset, 1)))) // Extract pool address (160 bits)
        }

        return Hop(isV3, direction, poolAddress);
    }

    /// @dev Processes the next hop in the sequence
    /// @param data The encoded data of the arbitrage request
    /// @param currentIndex The current index of the hop
    /// @return hasMoreHops True if there are more hops to process, false otherwise
    function hasNextHop(bytes calldata data, uint256 currentIndex)
        internal
        pure
        returns (bool hasMoreHops)
    {
        uint256 nextHopOffset = currentIndex + 21; // Each hop is 21 bytes
        return nextHopOffset + 21 <= data.length;
    }
}
