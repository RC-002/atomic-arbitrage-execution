// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IUniswapV3Pool.sol";
import "./interfaces/IUniswapV3SwapCallback.sol";
import "./libraries/ArbitrageRequestDecoder.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract FlashArbitrage is IUniswapV3SwapCallback {
    using ArbitrageRequestDecoder for bytes;

    address public immutable WETH;

    constructor(address _weth) {
        WETH = _weth;
    }

    /// @notice Executes an arbitrage sequence with flash swaps
    /// @param data Encoded hops data for the arbitrage
    function executeArbitrage(bytes calldata data) external {
        (uint256 amountIn, ArbitrageRequestDecoder.Hop memory firstHop) = data.decodeFirstHop();
        if (firstHop.isV3) {
            IUniswapV3Pool(firstHop.poolAddress).swap(
                address(this),
                firstHop.direction,
                int256(amountIn),
                firstHop.direction ? type(uint160).max : 0,
                data
            );
        } else {
            IUniswapV2Pair(firstHop.poolAddress).swap(
                firstHop.direction ? 0 : amountIn,
                firstHop.direction ? amountIn : 0,
                address(this),
                data
            );
        }
    }

    /// @dev Callback for Uniswap V3 swaps
    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) external override {
        ArbitrageRequestDecoder.Hop memory hop = data.decodeHop(0);
        require(msg.sender == hop.poolAddress, "Invalid callback sender");

        address tokenIn = hop.direction ? IUniswapV3Pool(msg.sender).token1() : IUniswapV3Pool(msg.sender).token0();
        uint256 amountToPay = uint256(hop.direction ? amount1Delta : amount0Delta);

        if (!data.processNextHop()) {
            IERC20(tokenIn).transfer(msg.sender, amountToPay);
        }
    }

    /// @dev Callback for Uniswap V2 swaps
    function uniswapV2Call(
        address sender,
        uint amount0,
        uint amount1,
        bytes calldata data
    ) external {
        require(sender == address(this), "Unauthorized caller");

        ArbitrageRequestDecoder.Hop memory hop = data.decodeHop(0);
        require(msg.sender == hop.poolAddress, "Invalid callback sender");

        address tokenIn = hop.direction ? IUniswapV2Pair(msg.sender).token1() : IUniswapV2Pair(msg.sender).token0();
        uint256 amountToPay = hop.direction ? amount1 : amount0;

        if (!data.processNextHop()) {
            IERC20(tokenIn).transfer(msg.sender, amountToPay);
        }
    }
}
