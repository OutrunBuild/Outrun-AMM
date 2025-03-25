//SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

interface IMemeverseLiquidityRouter {
    function factories(uint256 feeRate) external view returns (address);

    function previewLiquidityOut(
        address tokenA,
        address tokenB,
        uint256 feeRate,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin
    ) external view returns (uint256 liquidity, uint256 liquidityMin);

    function previewTokenIn(
        address tokenA,
        address tokenB,
        uint256 feeRate,
        uint256 liquidity
    ) external view returns (uint256 amountA, uint256 amountB, address pair);

    function addExactTokensForLiquidity(
        address tokenA,
        address tokenB,
        uint256 feeRate,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity);

    function addTokensForExactLiquidity(
        address tokenA,
        address tokenB,
        uint256 feeRate,
        uint256 liquidityDesired,
        uint256 amountAMax,
        uint256 amountBMax,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity);

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 feeRate,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB);

    function quote(
        uint256 amountA, 
        uint256 reserveA, 
        uint256 reserveB
    ) external pure returns (uint256 amountB);

    function getReserves(
        address factory, 
        address tokenA, 
        address tokenB,
        uint256 feeRate
    ) external view returns (uint256 reserveA, uint256 reserveB);

    function getAmountOut(
        uint256 amountIn, 
        uint256 reserveIn, 
        uint256 reserveOut,
        uint256 feeRate
    ) external pure returns (uint256 amountOut);

    function getAmountIn(
        uint256 amountOut, 
        uint256 reserveIn, 
        uint256 reserveOut,
        uint256 feeRate
    ) external pure returns (uint256 amountIn);

    error Expired();

    error NonExistentPair();

    error InsufficientAmount();

    error InsufficientBAmount();

    error InsufficientAAmount();

    error ExcessiveInputAmount();
    
    error InsufficientLiquidity();

    error InsufficientInputAmount();

    error InsufficientOutputAmount();
}
