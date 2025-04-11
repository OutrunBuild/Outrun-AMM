// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

interface IStandardizedYield {
    function deposit(
        address receiver,
        address tokenIn,
        uint256 amountTokenToDeposit,
        uint256 minSharesOut
    ) external payable returns (uint256 amountSharesOut);

    function previewDeposit(
        address tokenIn,
        uint256 amountTokenToDeposit
    ) external view returns (uint256 amountSharesOut);
}