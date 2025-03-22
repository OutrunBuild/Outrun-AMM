//SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

interface IMEVGuard {
    struct ExecutionDetail {
        bool isExecuted;
        uint248 nonce;
    }

    function execute(
        bool antiMEV,
        uint256 reserve0, 
        uint256 reserve1,
        uint256 amount0Out,
        uint256 amount1Out
    ) external returns (bool);

    function setPercentageValue(uint256 _percentageValue) external;

    function setFactory(address factory) external;

    function setAntiFrontBlockEdge(address pair, uint256 antiFrontBlockEdge) external;

    error PermissionDenied();
}
