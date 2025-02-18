//SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

interface IOutrunAMMCallee {
    function OutrunAMMCall(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external;
}
