//SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {TransferHelper} from "../libraries/TransferHelper.sol";
import {OutrunAMMLibrary} from "../libraries/OutrunAMMLibrary.sol";
import {IOutrunAMMPair} from "../core/interfaces/IOutrunAMMPair.sol";
import {IOutrunAMMERC20} from "../core/interfaces/IOutrunAMMERC20.sol";
import {IOutrunAMMFactory} from "../core/interfaces/IOutrunAMMFactory.sol";
import {IMemeverseLiquidityRouter} from "./interfaces/IMemeverseLiquidityRouter.sol";

/**
 * @dev Using for Memeverse liquidity
 */
contract MemeverseLiquidityRouter is IMemeverseLiquidityRouter {
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
        uint256 liquidityDesired,
        uint256 amountAMax,
        uint256 amountBMax,
        address to,
        uint256 deadline
    ) external override ensure(deadline) returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        address pair;
        (amountA, amountB, pair) = previewTokenIn(tokenA, tokenB, feeRate, liquidityDesired);
        require(amountA <= amountAMax && amountB <= amountBMax, ExcessiveInputAmount());
        TransferHelper.safeTransferFrom(tokenA, msg.sender, pair, amountA);
        TransferHelper.safeTransferFrom(tokenB, msg.sender, pair, amountB);
        liquidity = IOutrunAMMPair(pair).mint(to);
    }

    function _addLiquidity(
        address tokenA,
        address tokenB,
        uint256 feeRate,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin
    ) internal returns (uint256 amountA, uint256 amountB) {
        address factory = factories[feeRate];
        if (IOutrunAMMFactory(factory).getPair(tokenA, tokenB) == address(0)) {
            IOutrunAMMFactory(factory).createPair(tokenA, tokenB);
        }

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

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 feeRate,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external override ensure(deadline) returns (uint256 amountA, uint256 amountB) {
        address pair = OutrunAMMLibrary.pairFor(factories[feeRate], tokenA, tokenB, feeRate);
        IOutrunAMMERC20(pair).transferFrom(msg.sender, pair, liquidity); // send liquidity to pair
        (uint256 amount0, uint256 amount1) = IOutrunAMMPair(pair).burn(to);
        (address token0,) = OutrunAMMLibrary.sortTokens(tokenA, tokenB);
        (amountA, amountB) = tokenA == token0 ? (amount0, amount1) : (amount1, amount0);
        require(amountA >= amountAMin, InsufficientAAmount());
        require(amountB >= amountBMin, InsufficientBAmount());
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
}
