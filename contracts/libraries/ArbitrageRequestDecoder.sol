// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

library ArbitrageRequestDecoder {
    
    struct Hop {
        bool isV3; // true for Uniswap V3, false for V2
        bool direction; // true if selling token1, false if selling token0
        address poolAddress;
    }

    /// @dev Decodes the first hop and input amount from encoded data
    function decodeFirstHop(bytes calldata data) internal pure returns (uint256 amountIn, Hop memory hop) {
        amountIn = decodeAmountIn(data);
        hop = decodeHop(data, 16); // First hop starts after 16 bytes of `amountIn`
    }

    /// @dev Decodes a hop from the encoded data
    function decodeHop(bytes calldata data, uint offset) internal pure returns (Hop memory) {
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
    function processNextHop(bytes calldata data) internal pure returns (bool) {
        uint offset = decodeNextOffset(data);
        if (offset >= data.length) return false; // No more hops
        decodeHop(data, offset); // Process the next hop
        return true;
    }

    /// @dev Decodes the input amount for the first swap
    function decodeAmountIn(bytes calldata data) internal pure returns (uint256) {
        require(data.length >= 16, "Invalid data length for amountIn");
        uint256 amountIn;
        assembly {
            amountIn := calldataload(data.offset)
        }
        return amountIn;
    }

    /// @dev Decodes the offset for the next hop
    function decodeNextOffset(bytes calldata data) internal pure returns (uint) {
        require(data.length >= 32, "Invalid data length for offset");
        uint256 offset;
        assembly {
            offset := calldataload(add(data.offset, 16))
        }
        return offset;
    }
}