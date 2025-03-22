//SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

interface IOutrunAMMRouter {
    function factories(uint256 feeRate) external view returns (address);
    
    function WETH() external view returns (address);

    /**
     * addLiquidity *
     */
    function addLiquidity(
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

    function addLiquidityETH(
        address token,
        uint256 feeRate,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external payable returns (uint256 amountToken, uint256 amountETH, uint256 liquidity);

    /**
     * removeLiquidity *
     */
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

    function removeLiquidityETH(
        address token,
        uint256 feeRate,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountToken, uint256 amountETH);

    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint256 feeRate,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountETH);

    /**
     * swap *
     */
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        uint256[] calldata feeRates,
        address to,
        address referrer,
        uint256 deadline,
        bool antiMEV
    ) external returns (uint256[] memory amounts);

    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        uint256[] calldata feeRates,
        address to,
        address referrer,
        uint256 deadline,
        bool antiMEV
    ) external returns (uint256[] memory amounts);

    function swapExactETHForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        uint256[] calldata feeRates,
        address to,
        address referrer,
        uint256 deadline,
        bool antiMEV
    ) external payable returns (uint256[] memory amounts);

    function swapTokensForExactETH(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        uint256[] calldata feeRates,
        address to,
        address referrer,
        uint256 deadline,
        bool antiMEV
    ) external returns (uint256[] memory amounts);

    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        uint256[] calldata feeRates,
        address to,
        address referrer,
        uint256 deadline,
        bool antiMEV
    ) external returns (uint256[] memory amounts);

    function swapETHForExactTokens(
        uint256 amountOut,
        address[] calldata path,
        uint256[] calldata feeRates,
        address to,
        address referrer,
        uint256 deadline,
        bool antiMEV
    ) external payable returns (uint256[] memory amounts);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        uint256[] calldata feeRates,
        address to,
        address referrer,
        uint256 deadline,
        bool antiMEV
    ) external;

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint256 amountOutMin,
        address[] calldata path,
        uint256[] calldata feeRates,
        address to,
        address referrer,
        uint256 deadline,
        bool antiMEV
    ) external payable;

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        uint256[] calldata feeRates,
        address to,
        address referrer,
        uint256 deadline,
        bool antiMEV
    ) external;

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

    function getAmountsOut(
        uint256 amountIn, 
        address[] memory path,
        uint256[] memory feeRates
    ) external view returns (uint256[] memory amounts);

    function getAmountsIn(
        uint256 amountOut, 
        address[] memory path,
        uint256[] memory feeRates
    ) external view returns (uint256[] memory amounts);

    error Expired();

    error InvalidPath();

    error InvalidETHSender();

    error InsufficientAmount();

    error InsufficientBAmount();

    error InsufficientAAmount();

    error ExcessiveInputAmount();
    
    error InsufficientLiquidity();

    error InsufficientInputAmount();

    error InsufficientOutputAmount();
}
