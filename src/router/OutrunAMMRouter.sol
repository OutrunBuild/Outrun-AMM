//SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IWETH} from "../libraries/IWETH.sol";
import {IMEVGuard} from "../core/interfaces/IMEVGuard.sol";
import {TransferHelper} from "../libraries/TransferHelper.sol";
import {OutrunAMMLibrary} from "../libraries/OutrunAMMLibrary.sol";
import {IOutrunAMMRouter} from "./interfaces/IOutrunAMMRouter.sol";
import {IOutrunAMMPair} from "../core/interfaces/IOutrunAMMPair.sol";
import {IOutrunAMMERC20} from "../core/interfaces/IOutrunAMMERC20.sol";
import {IOutrunAMMFactory} from "../core/interfaces/IOutrunAMMFactory.sol";

contract OutrunAMMRouter is IOutrunAMMRouter {
    uint256 public constant RATIO = 10000;
    address public immutable WETH;
    address public immutable MEV_GUARD;

    mapping(uint256 feeRate => address) public factories;

    modifier ensure(uint256 deadline) {
        require(deadline >= block.timestamp, Expired());
        _;
    }

    constructor(
        address _factory0, 
        address _factory1, 
        address _WETH,
        address _guard
    ) {
        factories[30] = _factory0;      // 0.3%
        factories[100] = _factory1;     // 1%
        WETH = _WETH;
        MEV_GUARD = _guard;
    }

    receive() external payable {
        // only accept ETH via fallback from the WETH contract
        require(msg.sender == WETH, InvalidETHSender());
    }

    /**
     * ADD LIQUIDITY *
     */
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
        // create the pair if it doesn't exist yet
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
    ) external override ensure(deadline) returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        (amountA, amountB) = _addLiquidity(tokenA, tokenB, feeRate, amountADesired, amountBDesired, amountAMin, amountBMin);
        address pair = OutrunAMMLibrary.pairFor(factories[feeRate], tokenA, tokenB, feeRate);
        TransferHelper.safeTransferFrom(tokenA, msg.sender, pair, amountA);
        TransferHelper.safeTransferFrom(tokenB, msg.sender, pair, amountB);
        liquidity = IOutrunAMMPair(pair).mint(to);
    }

    function addLiquidityETH(
        address token,
        uint256 feeRate,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external payable override ensure(deadline) returns (uint256 amountToken, uint256 amountETH, uint256 liquidity) {
        (amountToken, amountETH) = _addLiquidity(token, WETH, feeRate, amountTokenDesired, msg.value, amountTokenMin, amountETHMin);
        address pair = OutrunAMMLibrary.pairFor(factories[feeRate], token, WETH, feeRate);
        TransferHelper.safeTransferFrom(token, msg.sender, pair, amountToken);
        IWETH(WETH).deposit{value: amountETH}();
        assert(IWETH(WETH).transfer(pair, amountETH));
        liquidity = IOutrunAMMPair(pair).mint(to);
        // refund dust eth, if any
        if (msg.value > amountETH) TransferHelper.safeTransferETH(msg.sender, msg.value - amountETH);
    }

    // **** REMOVE LIQUIDITY ****
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 feeRate,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) public override ensure(deadline) returns (uint256 amountA, uint256 amountB) {
        address pair = OutrunAMMLibrary.pairFor(factories[feeRate], tokenA, tokenB, feeRate);
        IOutrunAMMERC20(pair).transferFrom(msg.sender, pair, liquidity); // send liquidity to pair
        (uint256 amount0, uint256 amount1) = IOutrunAMMPair(pair).burn(to);
        (address token0,) = OutrunAMMLibrary.sortTokens(tokenA, tokenB);
        (amountA, amountB) = tokenA == token0 ? (amount0, amount1) : (amount1, amount0);
        require(amountA >= amountAMin, InsufficientAAmount());
        require(amountB >= amountBMin, InsufficientBAmount());
    }

    function removeLiquidityETH(
        address token,
        uint256 feeRate,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external override ensure(deadline) returns (uint256 amountToken, uint256 amountETH) {
        (amountToken, amountETH) = removeLiquidity(token, WETH, feeRate, liquidity, amountTokenMin, amountETHMin, address(this), deadline);
        TransferHelper.safeTransfer(token, to, amountToken);
        IWETH(WETH).withdraw(amountETH);
        TransferHelper.safeTransferETH(to, amountETH);
    }

    /**
     * REMOVE LIQUIDITY (supporting fee-on-transfer tokens) *
     */
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint256 feeRate,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external override ensure(deadline) returns (uint256 amountETH) {
        (, amountETH) = removeLiquidity(token, WETH, feeRate, liquidity, amountTokenMin, amountETHMin, address(this), deadline);
        TransferHelper.safeTransfer(token, to, IERC20(token).balanceOf(address(this)));
        IWETH(WETH).withdraw(amountETH);
        TransferHelper.safeTransferETH(to, amountETH);
    }

    /**
     * SWAP *
     */
    // requires the initial amount to have already been sent to the first pair
    function _swap(
        uint256[] memory amounts, 
        address[] memory path, 
        uint256[] memory feeRates, 
        address originTo, 
        address referrer,
        bool antiMEV
    ) internal returns (bool) {
        IMEVGuard(MEV_GUARD).setOriginTo(originTo);
        for (uint256 i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = OutrunAMMLibrary.sortTokens(input, output);
            uint256 amountOut = amounts[i + 1];
            (uint256 amount0Out, uint256 amount1Out) = input == token0 ? (uint256(0), amountOut) : (amountOut, uint256(0));
            address to = i < path.length - 2 ? OutrunAMMLibrary.pairFor(factories[feeRates[i + 1]], output, path[i + 2], feeRates[i + 1]) : originTo;
            if (!IOutrunAMMPair(OutrunAMMLibrary.pairFor(factories[feeRates[i]], input, output, feeRates[i])).swap(amount0Out, amount1Out, to, referrer, new bytes(0), antiMEV)) return false;
        }
        return true;
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        uint256[] calldata feeRates,
        address to,
        address referrer,
        uint256 deadline,
        bool antiMEV
    ) external override ensure(deadline) returns (uint256[] memory amounts) {
        amounts = getAmountsOut(amountIn, path, feeRates);
        require(amounts[amounts.length - 1] >= amountOutMin, InsufficientOutputAmount());
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, OutrunAMMLibrary.pairFor(factories[feeRates[0]], path[0], path[1], feeRates[0]), amounts[0]
        );
        _swap(amounts, path, feeRates, to, referrer, antiMEV);
    }

    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        uint256[] calldata feeRates,
        address to,
        address referrer,
        uint256 deadline,
        bool antiMEV
    ) external override ensure(deadline) returns (uint256[] memory amounts) {
        amounts = getAmountsIn(amountOut, path, feeRates);
        require(amounts[0] <= amountInMax, ExcessiveInputAmount());
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, OutrunAMMLibrary.pairFor(factories[feeRates[0]], path[0], path[1], feeRates[0]), amounts[0]
        );
        _swap(amounts, path, feeRates, to, referrer, antiMEV);
    }

    function swapExactETHForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        uint256[] calldata feeRates,
        address to,
        address referrer,
        uint256 deadline,
        bool antiMEV
    ) external payable override ensure(deadline) returns (uint256[] memory amounts) {
        require(path[0] == WETH, InvalidPath());
        amounts = getAmountsOut(msg.value, path, feeRates);
        require(amounts[amounts.length - 1] >= amountOutMin, InsufficientOutputAmount());
        IWETH(WETH).deposit{value: amounts[0]}();
        assert(IWETH(WETH).transfer(OutrunAMMLibrary.pairFor(factories[feeRates[0]], path[0], path[1], feeRates[0]), amounts[0]));
        _swap(amounts, path, feeRates, to, referrer, antiMEV);
    }

    function swapTokensForExactETH(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        uint256[] calldata feeRates,
        address to,
        address referrer,
        uint256 deadline,
        bool antiMEV
    ) external override ensure(deadline) returns (uint256[] memory amounts) {
        require(path[path.length - 1] == WETH, InvalidPath());
        amounts = getAmountsIn(amountOut, path, feeRates);
        require(amounts[0] <= amountInMax, ExcessiveInputAmount());
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, OutrunAMMLibrary.pairFor(factories[feeRates[0]], path[0], path[1], feeRates[0]), amounts[0]
        );
        if (_swap(amounts, path, feeRates, address(this), referrer, antiMEV)) {
            IWETH(WETH).withdraw(amounts[amounts.length - 1]);
            TransferHelper.safeTransferETH(to, amounts[amounts.length - 1]);
        }
    }

    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        uint256[] calldata feeRates,
        address to,
        address referrer,
        uint256 deadline,
        bool antiMEV
    ) external override ensure(deadline) returns (uint256[] memory amounts) {
        require(path[path.length - 1] == WETH, InvalidPath());
        amounts = getAmountsOut(amountIn, path, feeRates);
        require(amounts[amounts.length - 1] >= amountOutMin, InsufficientOutputAmount());
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, OutrunAMMLibrary.pairFor(factories[feeRates[0]], path[0], path[1], feeRates[0]), amounts[0]
        );
        if (_swap(amounts, path, feeRates, address(this), referrer, antiMEV)) {
            IWETH(WETH).withdraw(amounts[amounts.length - 1]);
            TransferHelper.safeTransferETH(to, amounts[amounts.length - 1]);
        }
    }

    function swapETHForExactTokens(
        uint256 amountOut,
        address[] calldata path,
        uint256[] calldata feeRates,
        address to,
        address referrer,
        uint256 deadline,
        bool antiMEV
    ) external payable override ensure(deadline) returns (uint256[] memory amounts) {
        require(path[0] == WETH, InvalidPath());
        amounts = getAmountsIn(amountOut, path, feeRates);
        require(amounts[0] <= msg.value, ExcessiveInputAmount());
        IWETH(WETH).deposit{value: amounts[0]}();
        assert(IWETH(WETH).transfer(OutrunAMMLibrary.pairFor(factories[feeRates[0]], path[0], path[1], feeRates[0]), amounts[0]));
        _swap(amounts, path, feeRates, to, referrer, antiMEV);
        // refund dust eth, if any
        if (msg.value > amounts[0]) TransferHelper.safeTransferETH(msg.sender, msg.value - amounts[0]);
    }

    /**
     * SWAP (supporting fee-on-transfer tokens) *
     */
    // requires the initial amount to have already been sent to the first pair
    function _swapSupportingFeeOnTransferTokens(address[] memory path, uint256[] memory feeRates, address originTo, address referrer, bool antiMEV) internal returns (bool) {
        IMEVGuard(MEV_GUARD).setOriginTo(originTo);
        for (uint256 i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = OutrunAMMLibrary.sortTokens(input, output);
            IOutrunAMMPair pair = IOutrunAMMPair(OutrunAMMLibrary.pairFor(factories[feeRates[i]], input, output, feeRates[i]));
            uint256 amountInput;
            uint256 amountOutput;
            {
                // scope to avoid stack too deep errors
                (uint256 reserve0, uint256 reserve1,) = pair.getReserves();
                (uint256 reserveInput, uint256 reserveOutput) = input == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
                amountInput = IERC20(input).balanceOf(address(pair)) - reserveInput;
                amountOutput = getAmountOut(amountInput, reserveInput, reserveOutput, feeRates[i]);
            }
            (uint256 amount0Out, uint256 amount1Out) = input == token0 ? (uint256(0), amountOutput) : (amountOutput, uint256(0));
            address to = i < path.length - 2 ? OutrunAMMLibrary.pairFor(factories[feeRates[i + 1]], output, path[i + 2], feeRates[i + 1]) : originTo;
            if(!pair.swap(amount0Out, amount1Out, to, referrer, new bytes(0), antiMEV)) return false;
        }
        return true;
    }

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        uint256[] calldata feeRates,
        address to,
        address referrer,
        uint256 deadline,
        bool antiMEV
    ) external override ensure(deadline) {
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, OutrunAMMLibrary.pairFor(factories[feeRates[0]], path[0], path[1], feeRates[0]), amountIn
        );
        uint256 balanceBefore = IERC20(path[path.length - 1]).balanceOf(to);
        _swapSupportingFeeOnTransferTokens(path, feeRates, to, referrer, antiMEV);
        require(
            IERC20(path[path.length - 1]).balanceOf(to) - balanceBefore >= amountOutMin,
            InsufficientOutputAmount()
        );
    }

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint256 amountOutMin,
        address[] calldata path,
        uint256[] calldata feeRates,
        address to,
        address referrer,
        uint256 deadline,
        bool antiMEV
    ) external payable override ensure(deadline) {
        require(path[0] == WETH, InvalidPath());
        uint256 amountIn = msg.value;
        IWETH(WETH).deposit{value: amountIn}();
        assert(IWETH(WETH).transfer(OutrunAMMLibrary.pairFor(factories[feeRates[0]], path[0], path[1], feeRates[0]), amountIn));
        uint256 balanceBefore = IERC20(path[path.length - 1]).balanceOf(to);
        _swapSupportingFeeOnTransferTokens(path, feeRates, to, referrer, antiMEV);
        require(
            IERC20(path[path.length - 1]).balanceOf(to) - balanceBefore >= amountOutMin,
            InsufficientOutputAmount()
        );
    }

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        uint256[] calldata feeRates,
        address to,
        address referrer,
        uint256 deadline,
        bool antiMEV
    ) external override ensure(deadline) {
        require(path[path.length - 1] == WETH, InvalidPath());
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, OutrunAMMLibrary.pairFor(factories[feeRates[0]], path[0], path[1], feeRates[0]), amountIn
        );
        if(_swapSupportingFeeOnTransferTokens(path, feeRates, address(this), referrer, antiMEV)) {
            uint256 amountOut = IERC20(WETH).balanceOf(address(this));
            require(amountOut >= amountOutMin, InsufficientOutputAmount());
            IWETH(WETH).withdraw(amountOut);
            TransferHelper.safeTransferETH(to, amountOut);
        }
    }

    // **** LIBRARY FUNCTIONS ****
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

    function getAmountsOut(
        uint256 amountIn, 
        address[] memory path,
        uint256[] memory feeRates
    ) public view override returns (uint256[] memory amounts) {
        require(
            path.length >= 2 &&
            feeRates.length >= 1 &&
            path.length == feeRates.length + 1, 
            InvalidPath()
        );

        amounts = new uint256[](path.length);
        amounts[0] = amountIn;
        for (uint256 i; i < path.length - 1; i++) {
            (uint256 reserveIn, uint256 reserveOut) = getReserves(factories[feeRates[i]], path[i], path[i + 1], feeRates[i]);
            amounts[i + 1] = getAmountOut(amounts[i], reserveIn, reserveOut, feeRates[i]);
        }
    }

    function getAmountsIn(
        uint256 amountOut, 
        address[] memory path, 
        uint256[] memory feeRates
    ) public view override returns (uint256[] memory amounts) {
        require(
            path.length >= 2 &&
            feeRates.length >= 1 &&
            path.length == feeRates.length + 1, 
            InvalidPath()
        );

        amounts = new uint256[](path.length);
        amounts[amounts.length - 1] = amountOut;
        for (uint256 i = path.length - 1; i > 0; i--) {
            (uint256 reserveIn, uint256 reserveOut) = getReserves(factories[feeRates[i]], path[i - 1], path[i], feeRates[i - 1]);
            amounts[i - 1] = getAmountIn(amounts[i], reserveIn, reserveOut, feeRates[i - 1]);
        }
    }
}
