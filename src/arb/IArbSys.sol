//SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

/**
* @title Precompiled contract that exists in every Arbitrum chain at address(100), 0x0000000000000000000000000000000000000064. Exposes a variety of system-level functionality.
 */
interface IArbSys {
    /**
    * @notice Get Arbitrum block number (distinct from L1 block number; Arbitrum genesis block has block number 0)
     */ 
    function arbBlockNumber() external view returns (uint256);

    /**
     * @notice Get Arbitrum block hash (distinct from L1 block hash)
     */ 
    function arbBlockHash(uint256 arbBlockNum) external view returns (bytes32);
}