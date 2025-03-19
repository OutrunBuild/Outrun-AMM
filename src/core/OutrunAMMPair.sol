//SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {UQ112x112} from "../libraries/UQ112x112.sol";
import {FixedPoint128} from "../libraries/FixedPoint128.sol";
import {Initializable} from "../libraries/Initializable.sol";
import {IOutrunAMMPair} from "./interfaces/IOutrunAMMPair.sol";
import {ReentrancyGuard} from "../libraries/ReentrancyGuard.sol";
import {IOutrunAMMCallee} from "./interfaces/IOutrunAMMCallee.sol";
import {IOutrunAMMFactory} from "./interfaces/IOutrunAMMFactory.sol";
import {IOutrunAMMERC20, OutrunAMMERC20} from "./OutrunAMMERC20.sol";
import {IFairModeExecutor} from "./interfaces/IFairModeExecutor.sol";

contract OutrunAMMPair is IOutrunAMMPair, OutrunAMMERC20, ReentrancyGuard, Initializable {
    using UQ112x112 for uint224;

    bytes4 private constant SELECTOR = bytes4(keccak256(bytes("transfer(address,uint256)")));
    uint256 public constant RATIO = 10000;
    uint256 public constant MINIMUM_LIQUIDITY = 1000;

    bool public fairMode;
    uint256 public initBlockNum;
    address public fairModeExecutor;

    address public factory;
    address public token0;
    address public token1;
    uint256 public swapFeeRate;

    uint112 private reserve0; // uses single storage slot, accessible via getReserves
    uint112 private reserve1; // uses single storage slot, accessible via getReserves
    uint32 private blockTimestampLast; // uses single storage slot, accessible via getReserves

    uint256 public price0CumulativeLast;
    uint256 public price1CumulativeLast;
    uint256 public kLast; // reserve0 * reserve1, as of immediately after the most recent liquidity event

    uint256 public feeGrowthX128; // accumulate maker fee per LP X128
    mapping(address account => uint256) public feeGrowthRecordX128; // record the feeGrowthX128 when calc maker's append fee
    mapping(address account => uint256) public unClaimedFeesX128;

    function getPairTokens() external view override returns (address _token0, address _token1) {
        _token0 = token0;
        _token1 = token1;
    }

    function getReserves() public view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _blockTimestampLast = blockTimestampLast;
    }

    /**
     * @dev Preview unclaimed maker fee
     */
    function previewMakerFee() external view override returns (uint256 amount0, uint256 amount1) {
        address msgSender = msg.sender;
        uint256 feeAppendX128 = balanceOf[msgSender] * (feeGrowthX128 - feeGrowthRecordX128[msgSender]);
        uint256 unClaimedFeeX128 = unClaimedFeesX128[msgSender];
        
        if (feeAppendX128 > 0) unClaimedFeeX128 += feeAppendX128;
        if (unClaimedFeeX128 == 0) return (0, 0);

        uint256 rootKLast = Math.sqrt(kLast);
        amount0 = Math.mulDiv(unClaimedFeeX128, IERC20(token0).balanceOf(address(this)), FixedPoint128.Q128 * rootKLast);
        amount1 = Math.mulDiv(unClaimedFeeX128, IERC20(token1).balanceOf(address(this)), FixedPoint128.Q128 * rootKLast);
    }

    // called once by the factory at time of deployment
    function initialize(
        address _token0, 
        address _token1, 
        address _fairModeExecutor,
        uint256 _swapFeeRate,
        bool _fairMode
    ) external initializer {
        require(_swapFeeRate < RATIO, FeeRateOverflow());

        token0 = _token0;
        token1 = _token1;
        fairModeExecutor = _fairModeExecutor;
        swapFeeRate = _swapFeeRate;
        fairMode = _fairMode;
        factory = msg.sender;
        initBlockNum = block.number;
    }

    /**
     * @dev Mint liquidity (LP)
     * @param to - address to receive LP token and calc this address's maker fee
     * @notice this low-level function should be called from a contract which performs important safety checks
     */
    function mint(address to) external nonReentrant returns (uint256 liquidity) {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves(); // gas savings
        uint256 balance0 = IERC20(token0).balanceOf(address(this));
        uint256 balance1 = IERC20(token1).balanceOf(address(this));
        uint256 amount0 = balance0 - _reserve0;
        uint256 amount1 = balance1 - _reserve1;

        if (to != address(0)) _calcFeeX128(to);
        if (totalSupply == 0) {
            liquidity = Math.sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY;
            _mint(address(0), MINIMUM_LIQUIDITY); // permanently lock the first MINIMUM_LIQUIDITY tokens
        } else {
            uint256 rootKLast = Math.sqrt(kLast);
            liquidity = Math.min(amount0 * rootKLast / _reserve0, amount1 * rootKLast / _reserve1);
        }

        require(liquidity > 0, InsufficientLiquidityMinted());

        _mint(to, liquidity);
        _update(balance0, balance1, _reserve0, _reserve1);

        kLast = uint256(reserve0) * uint256(reserve1); // reserve0 and reserve1 are up-to-date

        emit Mint(msg.sender, to, amount0, amount1);
    }

    /**
     * @dev Burn liquidity (LP) and withdraw token0 and token1
     * @param to - Address to receive token and calc this address's maker fee
     * @notice - this low-level function should be called from a contract which performs important safety checks
     */
    function burn(address to) external nonReentrant returns (uint256 amount0, uint256 amount1) {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        address _token0 = token0;
        address _token1 = token1;
        uint256 balance0 = IERC20(_token0).balanceOf(address(this));
        uint256 balance1 = IERC20(_token1).balanceOf(address(this));
        uint256 liquidity = balanceOf[address(this)];

        uint256 rootKLast = Math.sqrt(kLast);
        amount0 = liquidity * balance0 / rootKLast; // using balances ensures pro-rata distribution
        amount1 = liquidity * balance1 / rootKLast; // using balances ensures pro-rata distribution

        require(amount0 > 0 && amount1 > 0, InsufficientLiquidityBurned());

        _burn(address(this), liquidity);
        _safeTransfer(_token0, to, amount0);
        _safeTransfer(_token1, to, amount1);
        balance0 = IERC20(_token0).balanceOf(address(this));
        balance1 = IERC20(_token1).balanceOf(address(this));

        _update(balance0, balance1, _reserve0, _reserve1);

        kLast = uint256(reserve0) * uint256(reserve1); // reserve0 and reserve1 are up-to-date

        emit Burn(msg.sender, amount0, amount1, to);
    }

    /**
     * @dev Swap token
     * @param amount0Out - Amount of token0 output
     * @param amount1Out - Amount of token0 output
     * @param to - Address to output
     * @param referrer - Address of rebate referrer
     * @notice - this low-level function should be called from a contract which performs important safety checks
     */
    function swap(uint256 amount0Out, uint256 amount1Out, address to, address referrer, bytes calldata data) external nonReentrant {
        require(amount0Out > 0 || amount1Out > 0, InsufficientOutputAmount());
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        require(amount0Out < _reserve0 && amount1Out < _reserve1, InsufficientLiquidity());

        if (fairMode) IFairModeExecutor(fairModeExecutor).fairProcess(_reserve0, _reserve1, amount0Out, amount1Out);

        uint256 balance0;
        uint256 balance1;
        address _token0 = token0;
        address _token1 = token1;
        {
            require(to != _token0 && to != _token1, InvalidTo());

            if (amount0Out > 0) _safeTransfer(_token0, to, amount0Out);
            if (amount1Out > 0) _safeTransfer(_token1, to, amount1Out);
            if (data.length > 0) IOutrunAMMCallee(to).OutrunAMMCall(msg.sender, amount0Out, amount1Out, data);
            balance0 = IERC20(_token0).balanceOf(address(this));
            balance1 = IERC20(_token1).balanceOf(address(this));
        }

        uint256 amount0In;
        uint256 amount1In;
        unchecked {
            amount0In = balance0 > _reserve0 - amount0Out ? balance0 - (_reserve0 - amount0Out) : 0;
            amount1In = balance1 > _reserve1 - amount1Out ? balance1 - (_reserve1 - amount1Out) : 0;
        }
        require(amount0In > 0 || amount1In > 0, InsufficientInputAmount());
    
        uint256 rebateFee0;
        uint256 rebateFee1;
        uint256 protocolFee0;
        uint256 protocolFee1;
        uint256 _swapFeeRate = swapFeeRate;
        {
            uint256 balance0Adjusted = balance0 * RATIO - amount0In * _swapFeeRate;
            uint256 balance1Adjusted = balance1 * RATIO - amount1In * _swapFeeRate;
            
            require(
                balance0Adjusted * balance1Adjusted >= uint256(_reserve0) * uint256(_reserve1) * RATIO ** 2,
                ProductKLoss()
            );

            address feeTo = _feeTo();
            (balance0, rebateFee0, protocolFee0) = _transferRebateAndProtocolFee(amount0In, balance0, _token0, referrer, feeTo);
            (balance1, rebateFee1, protocolFee1) = _transferRebateAndProtocolFee(amount1In, balance1, _token1, referrer, feeTo);
        }

        _update(balance0, balance1, _reserve0, _reserve1);

        {
            uint256 k = uint256(reserve0) * uint256(reserve1);
            // The market-making revenue from LPs that are proactively burned will be distributed to others
            uint256 actualSupply = totalSupply - proactivelyBurnedAmount;
            actualSupply = actualSupply == 0 ? 1 : actualSupply;
            feeGrowthX128 += (Math.sqrt(k) - Math.sqrt(kLast)) * FixedPoint128.Q128 / actualSupply;
            kLast = k;
        }

        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
        emit ProtocolFee(referrer, rebateFee0, rebateFee1, protocolFee0, protocolFee1);
    }

    /**
     * @dev Claim all the maker fee of msgSender
     * @notice - Claim global protocol fee simultaneously
     */
    function claimMakerFee() external override returns (uint256 amount0, uint256 amount1) {
        address msgSender = msg.sender;
        _calcFeeX128(msgSender);

        uint256 feeX128 = unClaimedFeesX128[msgSender];
        if (feeX128 == 0) return (0, 0);
        unClaimedFeesX128[msgSender] = 0;

        address _token0 = token0;
        address _token1 = token1;
        uint256 balance0 = IERC20(_token0).balanceOf(address(this));
        uint256 balance1 = IERC20(_token1).balanceOf(address(this));
        uint256 rootKLast = Math.sqrt(kLast);

        Math.mulDiv(feeX128, balance0, FixedPoint128.Q128 * rootKLast);
        amount0 = Math.mulDiv(feeX128, balance0, FixedPoint128.Q128 * rootKLast);
        amount1 = Math.mulDiv(feeX128, balance1, FixedPoint128.Q128 * rootKLast);        
        require(amount0 > 0 && amount1 > 0, InsufficientMakerFeeClaimed());

        _safeTransfer(_token0, msgSender, amount0);
        _safeTransfer(_token1, msgSender, amount1);

        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        balance0 = IERC20(_token0).balanceOf(address(this));
        balance1 = IERC20(_token1).balanceOf(address(this));
        _update(balance0, balance1, _reserve0, _reserve1);

        kLast = uint256(reserve0) * uint256(reserve1);
    }

    /**
     * @dev Force balances to match reserves
     * @param to - Address to receive excess tokens
     */
    function skim(address to) external nonReentrant {
        address _token0 = token0; // gas savings
        address _token1 = token1; // gas savings
        _safeTransfer(_token0, to, IERC20(_token0).balanceOf(address(this)) - reserve0);
        _safeTransfer(_token1, to, IERC20(_token1).balanceOf(address(this)) - reserve1);
    }

    /**
     * @dev Force reserves to match balances
     */
    function sync() external nonReentrant {
        _update(IERC20(token0).balanceOf(address(this)), IERC20(token1).balanceOf(address(this)), reserve0, reserve1);
    }

    function _safeTransfer(address token, address to, uint256 value) internal {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(SELECTOR, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), TransferFailed());
    }

    /**
     * @dev update reserves and, on the first call per block, price accumulators
     */
    function _update(uint256 balance0, uint256 balance1, uint112 _reserve0, uint112 _reserve1) internal {
        require(balance0 <= type(uint112).max && balance1 <= type(uint112).max, Overflow());

        uint32 blockTimestamp;
        uint32 timeElapsed;
        unchecked {
            blockTimestamp = uint32(block.timestamp % 2 ** 32);
            timeElapsed = blockTimestamp - blockTimestampLast; // overflow is desired
        }
        if (timeElapsed > 0 && _reserve0 != 0 && _reserve1 != 0) {
            // * never overflows, and + overflow is desired
            unchecked {
                price0CumulativeLast += uint256(UQ112x112.encode(_reserve1).uqdiv(_reserve0)) * timeElapsed;
                price1CumulativeLast += uint256(UQ112x112.encode(_reserve0).uqdiv(_reserve1)) * timeElapsed;
            }
        }
        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
        blockTimestampLast = blockTimestamp;

        emit Sync(reserve0, reserve1);
    }

    /**
     * @dev Transfer rebate and protocol fee
     */
    function _transferRebateAndProtocolFee(
        uint256 amountIn,
        uint256 balance,
        address token,
        address referrer,
        address feeTo
    ) internal returns(uint256 balanceAfter, uint256 rebateFee, uint256 protocolFee) {
        if (amountIn == 0 || feeTo == address(0)) {
            return (balance, 0, 0);
        }

        uint256 _swapFeeRate = swapFeeRate;
        if (referrer == address(0)) {
            // swapFee * 25% as protocolFee
            rebateFee = 0;
            protocolFee = amountIn * _swapFeeRate / (RATIO * 4);
            balanceAfter = balance - protocolFee;
            _safeTransfer(token, feeTo, protocolFee);
        } else {
            // swapFee * 25% * 20% as rebateFee, swapFee * 25% * 80% as protocolFee
            rebateFee = amountIn * _swapFeeRate / (RATIO * 20);
            protocolFee = amountIn * _swapFeeRate / (RATIO * 5);
            balanceAfter = balance - rebateFee - protocolFee;
            _safeTransfer(token, referrer, rebateFee);
            _safeTransfer(token, feeTo, protocolFee);
        }
    }

    /**
     * @dev Calculate the maker fee
     */
    function _calcFeeX128(address to) internal {
        uint256 _feeGrowthX128 = feeGrowthX128;
        unchecked {
            uint256 feeAppendX128 = balanceOf[to] * (_feeGrowthX128 - feeGrowthRecordX128[to]);
            if (feeAppendX128 > 0) {
                unClaimedFeesX128[to] += feeAppendX128;
            }
        }
        feeGrowthRecordX128[to] = _feeGrowthX128;
    }

    function _feeTo() internal view returns (address) {
        return IOutrunAMMFactory(factory).feeTo();
    }

    function _beforeTokenTransfer(address from, address to, uint256) internal override {
        if (from != address(0)) _calcFeeX128(from);
        if (to != address(0)) _calcFeeX128(to);
    }
}