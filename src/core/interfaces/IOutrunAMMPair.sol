//SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

interface IOutrunAMMPair {
    function MINIMUM_LIQUIDITY() external pure returns (uint256);

    function factory() external view returns (address);

    function token0() external view returns (address);

    function token1() external view returns (address);

    function price0CumulativeLast() external view returns (uint256);

    function price1CumulativeLast() external view returns (uint256);

    function kLast() external view returns (uint256);

    function feeGrowthX128() external view returns (uint256);
    
    function getPairTokens() external view returns (address _token0, address _token1);

    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);

    function previewMakerFee() external view returns (uint256 amount0, uint256 amount1);


    function initialize(address token0, address token1, uint256 swapFeeRate, uint256 antiFrontBlockEdge, uint256 antiFrontPercentage) external;

    function mint(address to) external returns (uint256 liquidity);

    function burn(address to) external returns (uint256 amount0, uint256 amount1);

    function swap(uint256 amount0Out, uint256 amount1Out, address to, address referrer, bytes calldata data, bool antiMEV) external returns (bool);

    function skim(address to) external;

    function sync() external;

    function claimMakerFee() external returns (uint256 amount0, uint256 amount1);


    error Locked();

    error Overflow();

    error Forbidden();

    error InvalidTo();

    error ProductKLoss();

    error TransferFailed();

    error FeeRateOverflow();

    error InsufficientLiquidity();

    error InsufficientInputAmount();

    error InsufficientOutputAmount();

    error InsufficientUnclaimedFee();

    error InsufficientLiquidityMinted();

    error InsufficientLiquidityBurned();

    error InsufficientMakerFeeClaimed();


    event Mint(address indexed sender, address indexed to, uint256 amount0, uint256 amount1);

    event Burn(address indexed sender, uint256 amount0, uint256 amount1, address indexed to);

    event SwapInterrupted(
        address indexed sender,
        uint256 amount0In, 
        uint256 amount1In, 
        uint256 amount0Out, 
        uint256 amount1Out, 
        address indexed to
    );

    event Swap(
        address indexed sender,
        uint256 amount0In,
        uint256 amount1In,
        uint256 amount0Out,
        uint256 amount1Out,
        address indexed to
    );

    event ProtocolFee(
        address indexed referrer,
        uint256 rebateFee0,
        uint256 rebateFee1,
        uint256 protocolFee0,
        uint256 protocolFee1
    );

    event Sync(uint112 reserve0, uint112 reserve1);
}
