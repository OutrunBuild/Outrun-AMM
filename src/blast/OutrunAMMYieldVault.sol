//SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

import {TransferHelper} from "../libraries/TransferHelper.sol";
import {IOutrunAMMPair} from "./interfaces/IOutrunAMMPair.sol";
import {BlastGovernorable} from "../blast/BlastGovernorable.sol";
import {IOutrunAMMFactory} from "../core/interfaces/IOutrunAMMFactory.sol";
import {IOutrunAMMYieldVault} from "./interfaces/IOutrunAMMYieldVault.sol";

contract OutrunAMMYieldVault is IOutrunAMMYieldVault, BlastGovernorable {
    address public immutable SY_BETH;
    address public immutable SY_USDB;
    address public immutable FACTORY;

    constructor(
        address _SY_BETH, 
        address _SY_USDB, 
        address _FACTORY,
        address _blastGovernor
    ) BlastGovernorable(_blastGovernor) {
        SY_BETH = _SY_BETH;
        SY_USDB = _SY_USDB;
        FACTORY = _FACTORY;
    }

    function isValidPair(address pair) public view override returns (bool) {
        (address token0, address token1) = IOutrunAMMPair(pair).getPairTokens();
        (address tokenA, address tokenB) = token0 < token1 ? (token0, token1) : (token1, token0);
        return IOutrunAMMFactory(FACTORY).getPair(tokenA, tokenB) == pair;
    }

    function claimBETHNativeYield(address pair, address maker) external override {
        require(isValidPair(pair), InValidPair());
        require(maker != address(0) && pair != address(0), ZeroInput());
        
        IOutrunAMMPair(pair).updateAndDistributeYields(maker);
        (, uint128 accruedYield) = IOutrunAMMPair(pair).makerBETHNativeYields(maker);
        TransferHelper.safeTransfer(SY_BETH, maker, accruedYield);
        IOutrunAMMPair(pair).clearBETHNativeYield(maker);

        emit ClaimBETHNativeYield(pair, maker, accruedYield);
    }

    function claimUSDBNativeYield(address pair, address maker) external override {
        require(isValidPair(pair), InValidPair());
        require(maker != address(0) && pair != address(0), ZeroInput());

        IOutrunAMMPair(pair).updateAndDistributeYields(maker);
        (, uint128 accruedYield) = IOutrunAMMPair(pair).makerUSDBNativeYields(maker);
        TransferHelper.safeTransfer(SY_USDB, maker, accruedYield);
        IOutrunAMMPair(pair).clearUSDBNativeYield(maker);

        emit ClaimUSDBNativeYield(pair, maker, accruedYield);
    }
}