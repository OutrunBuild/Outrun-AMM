//SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

import {IFairModeExecutor} from "./interfaces/IFairModeExecutor.sol";

/**
 * @dev FairModeHook for Fair Swap
 */
contract FairModeExecutor is IFairModeExecutor {
    mapping(address factory => bool) factories;

    mapping(address pair => bool) fairPairs;

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
    ) external override returns (bool) {
        require(fairPairs[msg.sender], PermissionDenied());
        
        uint256 blockNum = block.number;
        ExecutionDetail memory latestExecutionDetail = executionDetails[blockNum - 1];
        executionDetails[blockNum].nonce++;

        // Only one transaction can succeed per block
        // Each transaction can purchase a maximum of 1% of the tokens in the liquidity pool
        if (latestExecutionDetail.isExecuted || amount0Out * 100 >  reserve0 || amount1Out * 100 >  reserve1) return false;
        
        // Integrating VRF into the Swap process significantly degrades the user experience. 
        // Pseudorandom numbers are sufficient because the probability of a successful transaction 
        // is determined by the number of attempted transactions in the previous block. When there 
        // are few participants, even if the pseudorandom numbers are manipulated, it makes little 
        // difference. When there are many participants, the difficulty of manipulation increases 
        // significantly.
        uint256 nonce = latestExecutionDetail.nonce == 0 ? 10000 : latestExecutionDetail.nonce;
        uint256 pseudoRandomNum = uint256(keccak256(abi.encodePacked(
            tx.origin,
            block.basefee,
            block.prevrandao,
            blockhash(blockNum - 1),
            nonce
        )));
        
        // The success probability is 1 / nonce
        bool isSuccess = pseudoRandomNum % nonce == 0;
        if (isSuccess) {
            executionDetails[blockNum].isExecuted == true;
            emit $_$(tx.origin);
        } else {
            emit P_P(tx.origin);
        }
        
        return isSuccess;
    }

    function setFairPair(address pair) external override {
        require(factories[msg.sender], PermissionDenied());
        fairPairs[pair] = true;
    }
}
