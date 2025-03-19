//SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

import {IFairModeExecutor} from "./interfaces/IFairModeExecutor.sol";

/**
 * @dev FairModeHook for Fair Swap
 */
contract FairModeExecutor is IFairModeExecutor {
    mapping(address pair => uint256) fairBlockNums;

    mapping(address factory => bool) factories;

    mapping(uint256 blockNum => ExecutionDetail) public executionDetails;

    constructor(address[] memory _factories) {
        for (uint256 i = 0; i < _factories.length; i++) {
            factories[_factories[i]] = true;
        }
    }

    function fairProcess(
        uint256 reserve0, 
        uint256 reserve1,
        uint256 amount0Out,
        uint256 amount1Out
    ) external override {
        uint256 blockNum = block.number;
        uint256 fairBlockNum = fairBlockNums[msg.sender];

        // Blocks beyond the FairBlock will no longer be processed fairly
        if(fairBlockNum == 0 || blockNum > fairBlockNum) return;

        ExecutionDetail memory executionDetail = executionDetails[blockNum - 1];
        executionDetails[blockNum].attemptCount++;

        // Only one transaction can succeed per block
        // Each transaction can purchase a maximum of 1% of the tokens in the liquidity pool
        require(
            !executionDetail.isExecuted &&
            amount0Out * 100 <  reserve0 && 
            amount1Out * 100 <  reserve1, 
            ExecutionLimit()
        );
        
        // Integrating VRF into the Swap process significantly degrades the user experience. 
        // Pseudorandom numbers are sufficient because the probability of a successful transaction 
        // is determined by the number of attempted transactions in the previous block. When there 
        // are few participants, even if the pseudorandom numbers are manipulated, it makes little 
        // difference. When there are many participants, the difficulty of manipulation increases 
        // significantly.
        uint256 pseudoRandomNum = uint256(keccak256(abi.encodePacked(
            tx.origin,
            block.basefee,
            block.prevrandao,
            blockhash(blockNum - 1)
        )));
        uint256 attemptCount = executionDetail.attemptCount == 0 ? 10000 : executionDetail.attemptCount;

        bool isSuccess = pseudoRandomNum % attemptCount == 0;
        if (!isSuccess) emit P_P(tx.origin);
        require(isSuccess, PityyyP_P());
        executionDetails[blockNum].isExecuted == true;

        emit $_$(tx.origin);
    }

    function setFairBlockNum(address pair, uint256 fairBlockCount) external override {
        require(factories[msg.sender], PermissionDenied());
        fairBlockNums[pair] += fairBlockCount;
    }
}
