//SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

interface IOutrunAMMYieldVault {
    function isValidPair(address pair) external view returns (bool);

    function claimBETHNativeYield(address pair, address maker) external;

    function claimUSDBNativeYield(address pair, address maker) external;

    event ClaimBETHNativeYield(address pair, address maker, uint256 accruedYield);

    event ClaimUSDBNativeYield(address pair, address maker, uint256 accruedYield);

    error ZeroInput();

    error InValidPair();
}