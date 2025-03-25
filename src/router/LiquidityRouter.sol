//SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {TransferHelper} from "../libraries/TransferHelper.sol";
import {OutrunAMMLibrary} from "../libraries/OutrunAMMLibrary.sol";
import {ILiquidityRouter} from "./interfaces/ILiquidityRouter.sol";
import {IOutrunAMMPair} from "../core/interfaces/IOutrunAMMPair.sol";
import {IOutrunAMMFactory} from "../core/interfaces/IOutrunAMMFactory.sol";

/**
 * @dev Use for minting POL tokens
 */
contract LiquidityRouter is ILiquidityRouter {
    uint256 public constant RATIO = 10000;

    mapping(uint256 feeRate => address) public factories;

    modifier ensure(uint256 deadline) {
        require(deadline >= block.timestamp, Expired());
        _;
    }

    constructor(address factory0, address factory1) {
        factories[30] = factory0;      // 0.3%
        factories[100] = factory1;     // 1%
    }

    /**
     * @dev Estimating the output amount of LP tokens based on the added token quantities
     */
    function previewLiquidityOut(
        address tokenA,
        address tokenB,
        uint256 feeRate,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin
    ) external view override returns (uint256 liquidity, uint256 liquidityMin) {
        address factory = factories[feeRate];
        address pair = IOutrunAMMFactory(factory).getPair(tokenA, tokenB);
        require(pair != address(0), NonExistentPair());

        uint256 amountA;
        uint256 amountB;
        (uint256 reserveA, uint256 reserveB) = getReserves(factory, tokenA, tokenB, feeRate);
        uint256 amountBOptimal = quote(amountADesired, reserveA, reserveB);
        if (amountBOptimal <= amountBDesired) {
            require(amountBOptimal >= amountBMin, InsufficientBAmount());
            (amountA, amountB) = (amountADesired, amountBOptimal);
        } else {
             uint256 amountAOptimal = quote(amountBDesired, reserveB, reserveA);
            assert(amountAOptimal <= amountADesired);
            require(amountAOptimal >= amountAMin, InsufficientAAmount());
            (amountA, amountB) = (amountAOptimal, amountBDesired);
        }

        uint256 rootKLast = Math.sqrt(IOutrunAMMPair(pair).kLast());
        liquidity = Math.min(amountA * rootKLast / reserveA, amountB * rootKLast / reserveB);
        liquidityMin = Math.min(Math.sqrt(amountADesired * amountBMin), Math.sqrt(amountBDesired * amountAMin));
    }

    /**
     * @dev Estimating the added token quantities based on the output amount of LP tokens
     */
    function previewTokenIn(
        address tokenA,
        address tokenB,
        uint256 feeRate,
        uint256 liquidity
    ) public view override returns (uint256 amountA, uint256 amountB, address pair) {
        address factory = factories[feeRate];
        pair = IOutrunAMMFactory(factory).getPair(tokenA, tokenB);
        require(pair != address(0), NonExistentPair());

        (uint256 reserveA, uint256 reserveB) = getReserves(factory, tokenA, tokenB, feeRate);
        uint256 rootKLast = Math.sqrt(IOutrunAMMPair(pair).kLast());
        amountA = liquidity * reserveA / rootKLast;
        amountB = liquidity * reserveB / rootKLast;
    }

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
    ) external override ensure(deadline) returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        (amountA, amountB) = _addLiquidity(tokenA, tokenB, feeRate, amountADesired, amountBDesired, amountAMin, amountBMin);
        address pair = OutrunAMMLibrary.pairFor(factories[feeRate], tokenA, tokenB, feeRate);
        TransferHelper.safeTransferFrom(tokenA, msg.sender, pair, amountA);
        TransferHelper.safeTransferFrom(tokenB, msg.sender, pair, amountB);
        liquidity = IOutrunAMMPair(pair).mint(to);
    }

    function addTokensForExactLiquidity(
        address tokenA,
        address tokenB,
        uint256 feeRate,
        uint256 liquidity,
        uint256 amountAMax,
        uint256 amountBMax,
        address to,
        uint256 deadline
    ) external override ensure(deadline) returns (uint256, uint256) {
        (uint256 amountA, uint256 amountB, address pair) = previewTokenIn(tokenA, tokenB, feeRate, liquidity);
        require(amountA <= amountAMax && amountB <= amountBMax, ExcessiveInputAmount());
        TransferHelper.safeTransferFrom(tokenA, msg.sender, pair, amountA);
        TransferHelper.safeTransferFrom(tokenB, msg.sender, pair, amountB);
        IOutrunAMMPair(pair).mint(to);
        return (amountA, amountB);
    }

    function _addLiquidity(
        address tokenA,
        address tokenB,
        uint256 feeRate,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin
    ) internal view returns (uint256 amountA, uint256 amountB) {
        address factory = factories[feeRate];
        require(IOutrunAMMFactory(factory).getPair(tokenA, tokenB) != address(0), NonExistentPair());

        (uint256 reserveA, uint256 reserveB) = getReserves(factory, tokenA, tokenB, feeRate);
        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            uint256 amountBOptimal = quote(amountADesired, reserveA, reserveB);
            if (amountBOptimal <= amountBDesired) {
                require(amountBOptimal >= amountBMin, InsufficientBAmount());
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint256 amountAOptimal = quote(amountBDesired, reserveB, reserveA);
                assert(amountAOptimal <= amountADesired);
                require(amountAOptimal >= amountAMin, InsufficientAAmount());
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }

    function quote(
        uint256 amountA, 
        uint256 reserveA, 
        uint256 reserveB
    ) public pure override returns (uint256 amountB) {
        require(amountA > 0, InsufficientAmount());
        require(reserveA > 0 && reserveB > 0, InsufficientLiquidity());
        amountB = amountA * reserveB / reserveA;
    }

    function getReserves(
        address factory, 
        address tokenA, 
        address tokenB,
        uint256 feeRate
    ) public view override returns (uint256 reserveA, uint256 reserveB) {
        (address token0,) = OutrunAMMLibrary.sortTokens(tokenA, tokenB);
        (uint256 reserve0, uint256 reserve1,) = IOutrunAMMPair(OutrunAMMLibrary.pairFor(factory, tokenA, tokenB, feeRate)).getReserves();
        (reserveA, reserveB) = tokenA == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
    }

    function getAmountOut(
        uint256 amountIn, 
        uint256 reserveIn, 
        uint256 reserveOut, 
        uint256 feeRate
    ) public pure override returns (uint256 amountOut) {
        require(amountIn > 0, InsufficientInputAmount());
        require(reserveIn > 0 && reserveOut > 0, InsufficientLiquidity());
        uint256 amountInWithFee = amountIn * (RATIO - feeRate);
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn * RATIO + amountInWithFee;
        amountOut = numerator / denominator;
    }

    function getAmountIn(
        uint256 amountOut, 
        uint256 reserveIn, 
        uint256 reserveOut, 
        uint256 feeRate
    ) public pure override returns (uint256 amountIn) {
        require(amountOut > 0, InsufficientOutputAmount());
        require(reserveIn > 0 && reserveOut > 0, InsufficientLiquidity());
        uint256 numerator = reserveIn * amountOut * RATIO;
        uint256 denominator = (reserveOut - amountOut) * (RATIO - feeRate);
        amountIn = (numerator / denominator) + 1;
    }
}
