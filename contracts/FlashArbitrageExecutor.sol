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
        executeArbitrageHop(amountIn, firstHop, data, 32 + 21);

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
        ArbitrageRequestDecoder.Hop memory hop = data.decodeHop(32); // First hop starts after 32 bytes
        require(msg.sender == hop.poolAddress, "Invalid callback sender");

        address tokenIn = hop.direction ? IUniswapV3Pool(msg.sender).token1() : IUniswapV3Pool(msg.sender).token0();
        uint256 amountToPayInThisHop = uint256(hop.direction ? amount1Delta : amount0Delta);
        uint256 amountInForNextHop = uint256(hop.direction ? amount0Delta : amount1Delta);

        // Process the next hop or complete the sequence
        if (data.hasNextHop(32)) {
            executeArbitrageHop(amountInForNextHop, data.decodeHop(53), data, 53 + 21);
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

        ArbitrageRequestDecoder.Hop memory hop = data.decodeHop(32); // First hop starts after 32 bytes
        require(msg.sender == hop.poolAddress, "Invalid callback sender");

        address tokenIn = hop.direction ? IUniswapV2Pair(msg.sender).token1() : IUniswapV2Pair(msg.sender).token0();
        uint256 amountToPayInThisHop = hop.direction ? amount1 : amount0;
        uint256 amountInForNextHop = hop.direction ? amount0 : amount1;

        // Process the next hop or complete the sequence
        if (data.hasNextHop(32)) {
            executeArbitrageHop(amountInForNextHop, data.decodeHop(53), data, 53 + 21);
        }

        // Pay the owed amount to the pool
        IERC20(tokenIn).transfer(msg.sender, amountToPayInThisHop);
    }

    /// @dev Executes an arbitrage hop
    /// @param amountIn Amount of tokens to input
    /// @param hop Hop details
    /// @param nextHopData Data for subsequent hops
    function executeArbitrageHop(
        uint256 amountIn,
        ArbitrageRequestDecoder.Hop memory hop,
        bytes calldata nextHopData,
        uint256 /* offset */ // Unused parameter removed to silence warning
    ) internal {
        if (hop.isV3) {
            IUniswapV3Pool(hop.poolAddress).swap(
                address(this),
                hop.direction,
                int256(amountIn),
                hop.direction ? type(uint160).max : 0,
                nextHopData
            );
        } else {
            IUniswapV2Pair(hop.poolAddress).swap(
                hop.direction ? 0 : amountIn,
                hop.direction ? amountIn : 0,
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
