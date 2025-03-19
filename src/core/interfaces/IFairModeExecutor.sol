//SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

interface IFairModeExecutor {
    struct ExecutionDetail {
        bool isExecuted;
        uint248 attemptCount;
    }

    function fairProcess(
        uint256 reserve0, 
        uint256 reserve1,
        uint256 amount0Out,
        uint256 amount1Out
    ) external;

    function setFairBlockNum(address pair, uint256 fairBlockCount) external;


    error ExecutionLimit();

    error PermissionDenied();

    error PityyyP_P();


    event P_P(address indexed user);

    event $_$(address indexed user);
}