// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IUniswapV3Pool.sol";
import "./interfaces/IUniswapV3SwapCallback.sol";
import "./libraries/ArbitrageRequestDecoder.sol";
import "./libraries/TickMath.sol";
import "./token/ERC20/IERC20.sol";

contract FlashArbitrageExecutor is IUniswapV3SwapCallback {
    using ArbitrageRequestDecoder for bytes;

    address public immutable WETH;
    address public immutable safeAddress;
    mapping(address => bool) private whitelist;

    constructor(address _weth, address _safeAddress) {
        require(_weth != address(0), "WETH address cannot be zero");
        require(_safeAddress != address(0), "Safe address cannot be zero");
        WETH = _weth;
        safeAddress = _safeAddress;
    }

    /// @dev Modifier to restrict access to the safe address
    modifier onlySafe() {
        require(msg.sender == safeAddress, "Caller is not the safe address");
        _;
    }

    /// @dev Modifier to restrict access to whitelisted addresses
    modifier onlyWhitelisted() {
        require(whitelist[msg.sender], "Caller is not whitelisted");
        _;
    }

    /// @notice Adds an address to the whitelist (only callable by the safe address)
    function addToWhitelist(address account) external onlySafe {
        require(account != address(0), "Invalid address");
        whitelist[account] = true;
        emit Whitelisted(account, true);
    }

    /// @notice Removes an address from the whitelist (only callable by the safe address)
    function removeFromWhitelist(address account) external onlySafe {
        require(whitelist[account], "Address not in whitelist");
        whitelist[account] = false;
        emit Whitelisted(account, false);
    }

    /// @notice Executes an arbitrage sequence with flash swaps
    /// @param data Encoded data for the arbitrage
    function executeAtomicArbitrageSwap(bytes calldata data) external onlyWhitelisted {
        uint256 balanceBeforeArbitrageSwaps = IERC20(WETH).balanceOf(address(this));

        // Decode and execute the first hop
        (uint256 amountIn, uint256 minIncreaseInWeth, ArbitrageRequestDecoder.Hop memory firstHop) = data.decodeFirstHop();

        // Slice out and concatenate data[:16] and data[32:]
        bytes memory arbitrageHopCalldata = new bytes(data.length - 16);
        assembly {
            let offset32 := add(data.offset, 32) // Skip the first 32 bytes
            let offset16 := data.offset // Start at the beginning (0 bytes)

            let length32 := sub(data.length, 32) // Length of data[32:]
            let length16 := 16 // Length of data[:16]

            // Allocate memory for the result
            let result := add(arbitrageHopCalldata, 32)
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


        executeArbitrageHop(amountIn + minIncreaseInWeth, firstHop, arbitrageHopCalldata); // Slice the first 32 bytes of calldata

        uint256 balanceAfterArbitrageSwaps = IERC20(WETH).balanceOf(address(this));

        // Ensure the WETH balance increased by at least `minIncreaseInWeth`
        require(balanceAfterArbitrageSwaps >= balanceBeforeArbitrageSwaps + minIncreaseInWeth, "Arbitrage did not meet profit requirement");
    }

    /// @dev Callback for Uniswap V3 swaps
    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) external override {
        ArbitrageRequestDecoder.Hop memory hop = data.decodeHop(); // Decode the next hop
        require(msg.sender == hop.poolAddress, "Invalid callback sender");

        address tokenIn = hop.direction ? IUniswapV3Pool(msg.sender).token0() : IUniswapV3Pool(msg.sender).token1();
        uint256 amountToPayInThisHop = amount1Delta > 0 ? uint256(amount1Delta) : uint256(amount0Delta);

        // Slice out the used part (21 bytes for the hop)
        data = data[21:];

        // Process the next hop or complete the sequence
        if (data.hasNextHop()) {
            executeArbitrageHop(amountToPayInThisHop, data.decodeHop(), data);            
        }

        // Pay the owed amount to the pool
        IERC20(tokenIn).transfer(msg.sender, amountToPayInThisHop);
    }

    /// @dev Callback for Uniswap V2 swaps
    function uniswapV2Call(
        address sender,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external {
        require(sender == address(this), "Unauthorized caller");

        ArbitrageRequestDecoder.Hop memory hop = data.decodeHop(); // Decode the next hop
        require(msg.sender == hop.poolAddress, "Invalid callback sender");

        address tokenIn = hop.direction ? IUniswapV2Pair(msg.sender).token0() : IUniswapV2Pair(msg.sender).token1();
        uint256 amountToPayInThisHop = hop.direction ? amount1 : amount0;

        // Slice out the used part (21 bytes for the hop)
        data = data[21:];

        // Process the next hop or complete the sequence
        if (data.hasNextHop()) {
            executeArbitrageHop(amountToPayInThisHop, data.decodeHop(), data);
        } else {
            amountToPayInThisHop = data.decodeU128data();
        }
        
        // Pay the owed amount to the pool
        IERC20(tokenIn).transfer(msg.sender, amountToPayInThisHop);
    }

    /// @dev Executes an arbitrage hop
    /// @param amountOut Amount of tokens that we receive from the swap
    /// @param hop Hop details
    /// @param nextHopData Data for subsequent hops
    function executeArbitrageHop(
        uint256 amountOut,
        ArbitrageRequestDecoder.Hop memory hop,
        bytes memory nextHopData
    ) internal {
        if (hop.isV3) {
            IUniswapV3Pool(hop.poolAddress).swap(
                address(this),
                hop.direction,
                - int256(amountOut), // This is now an exactOutput swap
                hop.direction ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1,
                nextHopData
            );
        } else {
            IUniswapV2Pair(hop.poolAddress).swap(
                hop.direction ? 0 : amountOut,
                hop.direction ? amountOut : 0,
                address(this),
                nextHopData
            );
        }
    }

    /// @notice Checks if an address is whitelisted
    function isWhitelisted(address account) external view returns (bool) {
        return whitelist[account];
    }

    /// @dev Emitted when an address is added to or removed from the whitelist
    event Whitelisted(address indexed account, bool isWhitelisted);
}
