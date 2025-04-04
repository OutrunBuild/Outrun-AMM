//SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

/**
 * @dev Interface of MEV Guard
 */
interface IMEVGuard {
    struct ExecutionDetail {
        bool isExecuted;
        uint248 requestNum;
    }

    function defend(
        bool antiMEV,
        uint256 reserve0, 
        uint256 reserve1,
        uint256 amount0Out,
        uint256 amount1Out
    ) external returns (bool);

    function antiFrontDefendBlock() external view returns (uint256);

    function antiMEVFeePercentage() external view returns (uint256);

    function antiMEVAmountOutLimitRate() external view returns (uint256);

    function originTo() external view returns (address);

    function setOriginTo(address originTo) external;

    function setFactoryStatus(address factory, bool status) external;

    function setAntiFrontDefendBlockEdge(address pair, uint256 antiFrontDefendBlockEdge) external;

    function setAntiFrontDefendBlock(uint256 antiFrontDefendBlock) external;

    function setAntiMEVFeePercentage(uint256 antiMEVFeePercentage) external;

    function setAntiMEVAmountOutLimitRate(uint256 antiMEVAmountOutLimitRate) external;

    
    error BlockLimit();

    error PermissionDenied();

    error TransactionSizeTooSmall();
}
