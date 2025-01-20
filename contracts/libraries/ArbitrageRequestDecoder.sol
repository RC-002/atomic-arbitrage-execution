// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

library ArbitrageRequestDecoder {
    struct Hop {
        bool isV3; // true for Uniswap V3, false for V2
        bool direction; // true if selling token1, false if selling token0
        address poolAddress; // Address of the pool
    }

    /// @dev Decodes the first hop, input amount, and minimum WETH balance increase
    function decodeFirstHop(bytes calldata data)
        internal
        pure
        returns (uint256 amountIn, uint256 minIncreaseInWeth, Hop memory hop)
    {
        amountIn = decodeAmountIn(data);
        minIncreaseInWeth = decodeMinIncreaseInWeth(data);
        hop = decodeHop(data, 32); // First hop starts after 32 bytes (`amountIn` + `minWethOut`)
    }

    /// @dev Decodes a hop from the encoded data
    /// @param data Encoded calldata
    /// @param offset Offset to start reading the hop from
    function decodeHop(bytes calldata data, uint256 offset)
        internal
        pure
        returns (Hop memory)
    {
        require(data.length >= offset + 21, "Invalid data length for hop");

        bool isV3 = (uint8(data[offset]) & 0x80) != 0;
        bool direction = (uint8(data[offset]) & 0x40) != 0;

        address poolAddress;
        assembly {
            poolAddress := shr(96, calldataload(add(data.offset, add(offset, 1))))
        }

        return Hop(isV3, direction, poolAddress);
    }

    /// @dev Processes the next hop in the sequence
    /// @param data Encoded calldata
    /// @param currentOffset Current offset in the calldata
    /// @return nextOffset Offset of the next hop, if exists
    /// @return hasMoreHops True if more hops are present, false otherwise
    function processNextHop(bytes calldata data, uint256 currentOffset)
        internal
        pure
        returns (uint256 nextOffset, bool hasMoreHops)
    {
        uint256 nextHopOffset = currentOffset + 21; // Each hop is 21 bytes
        if (nextHopOffset >= data.length) {
            return (0, false); // No more hops
        }
        return (nextHopOffset, true); // Return next hop offset and flag
    }

    /// @dev Decodes the input amount for the first swap
    /// @param data Encoded calldata
    /// @return amountIn Input amount for the first swap
    function decodeAmountIn(bytes calldata data)
        internal
        pure
        returns (uint256 amountIn)
    {
        require(data.length >= 16, "Invalid data length for amountIn");
        assembly {
            amountIn := calldataload(data.offset)
        }
    }

    /// @dev Decodes the minimum WETH balance increase
    /// @param data Encoded calldata
    /// @return minIncreaseInWeth Minimum required WETH balance increase
    function decodeMinIncreaseInWeth(bytes calldata data)
        internal
        pure
        returns (uint256 minIncreaseInWeth)
    {
        require(data.length >= 32, "Invalid data length for minIncreaseInWeth");
        assembly {
            minIncreaseInWeth := calldataload(add(data.offset, 16))
        }
    }
}
