//SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

interface IFairModeExecutor {
    struct ExecutionDetail {
        bool isExecuted;
        uint248 nonce;
    }

    function fairProcess(
        uint256 reserve0, 
        uint256 reserve1,
        uint256 amount0Out,
        uint256 amount1Out
    ) external returns (bool);

    function setFairPair(address pair) external;

    error PermissionDenied();

    event P_P(address indexed user);

    event $_$(address indexed user);
}