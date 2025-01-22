// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IUniswapV3Pool.sol";
import "./interfaces/IUniswapV2Callee.sol";
import "./interfaces/IUniswapV3SwapCallback.sol";
import "./libraries/ArbitrageRequestDecoder.sol";
import "./libraries/TickMath.sol";
import "./libraries/UniswapV2Library.sol";
import "./token/ERC20/IERC20.sol";

contract FlashArbitrageExecutor is IUniswapV3SwapCallback, IUniswapV2Callee {
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
        data = data[32:]; // slice the first 32 bytes because they are already decoded

        executeArbitrageHop(amountIn + minIncreaseInWeth, firstHop, data); // Slice the first 32 bytes of calldata

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
        uint256 amountToPayInThisHop = findUniswapV2AmountIn(msg.sender, amount0, amount1, hop.direction);

        // Slice out the used part (21 bytes for the hop)
        data = data[21:];

        // Process the next hop or complete the sequence
        if (data.hasNextHop()) {
            executeArbitrageHop(amountToPayInThisHop, data.decodeHop(), data);
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


    /// @notice Calculates the required input amount for a Uniswap V2 swap given the output amount and pool reserves
    /// @dev Determines the reserves and calculates the input amount using the UniswapV2Library
    /// @param pool The address of the Uniswap V2 pair contract
    /// @param amount0 The amount of token0 to be swapped (used when zeroForOne is false)
    /// @param amount1 The amount of token1 to be swapped (used when zeroForOne is true)
    /// @param zeroForOne Indicates the direction of the swap (true for token0 -> token1, false for token1 -> token0)
    /// @return amountIn The calculated input amount required to execute the swap
    function findUniswapV2AmountIn(address pool, uint256 amount0, uint256 amount1, bool zeroForOne) internal view returns (uint256 amountIn) {

        // Decode reserves from the pool
        uint112 reserve0;
        uint112 reserve1;
        (reserve0, reserve1, ) = IUniswapV2Pair(pool).getReserves();

        uint reserveIn;
        uint reserveOut;
        uint amountOut;

        // Assign reserves and output amount based on the direction of the swap
        if (zeroForOne) {
            reserveIn = uint(reserve0);
            reserveOut = uint(reserve1);
            amountOut = uint(amount1);
        } else {
            reserveIn = uint(reserve1);
            reserveOut = uint(reserve0);
            amountOut = uint(amount0);
        }

        // Use the UniswapV2Library to calculate the input amount
        amountIn = UniswapV2Library.getAmountIn(amountOut, reserveIn, reserveOut);
    }


    /// @notice Transfers all WETH held by this contract to the safe address
    /// @dev Can only be called by the safe address due to the `onlySafe` modifier
    function redeemWETH() external onlySafe {
        // Get the WETH balance of this contract
        uint256 wethBalance = IERC20(WETH).balanceOf(address(this));

        // Ensure there is some balance to transfer
        require(wethBalance > 0, "redeemWETH: No WETH balance to redeem");

        // Transfer the entire WETH balance to the safe
        IERC20(WETH).transfer(msg.sender, wethBalance);
    }


    /// @dev Emitted when an address is added to or removed from the whitelist
    event Whitelisted(address indexed account, bool isWhitelisted);
}
