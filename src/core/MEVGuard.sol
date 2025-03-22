//SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {IMEVGuard} from "./interfaces/IMEVGuard.sol";

/**
 * @dev MEV Guard
 */
contract MEVGuard is IMEVGuard, Nonces, Ownable {
    uint256 public percentageValue; // Success probability is percentageValue%

    mapping(address factory => bool) public factories;

    mapping(address pair => uint256) public antiFrontBlockEdges;

    mapping(uint256 blockNum => ExecutionDetail) private executionDetails;

    constructor(
        address _owner, 
        uint256 _percentageValue,
        address[] memory _factories
    ) Ownable(_owner) {
        percentageValue = _percentageValue;
        for (uint256 i = 0; i < _factories.length; i++) {
            factories[_factories[i]] = true;
        }
    }

    function execute(
        bool antiMEV,
        uint256 reserve0, 
        uint256 reserve1,
        uint256 amount0Out,
        uint256 amount1Out
    ) external override returns (bool) {
        uint256 antiFrontBlockEdge = antiFrontBlockEdges[msg.sender];
        require(antiFrontBlockEdge != 0, PermissionDenied());
        
        uint256 currentBlockNum = block.number;

        // Only one transaction can succeed per block before antiFrontBlockEdge, or the previous 
        // successful transaction did not enable anti-MEV.
        if (executionDetails[currentBlockNum].isExecuted) return false;

        // Anti-Front Running
        if (currentBlockNum < antiFrontBlockEdge) {
            executionDetails[currentBlockNum].nonce++;
            
            if (executionDetails[currentBlockNum].isExecuted) return false;

            // Each transaction can purchase a maximum of 1% of the tokens in the liquidity pool
            // before antiFrontBlockEdge.
            if (amount0Out * 100 >  reserve0 || amount1Out * 100 > reserve1) return false;

            // Integrating VRF into the Swap process significantly degrades the user experience. 
            // Pseudorandom numbers are sufficient because the parameters for generating random 
            // numbers are complex enough.
            uint256 latestExecutionNonce = executionDetails[currentBlockNum - 1].nonce;
            uint256 pseudoRandomNum = uint256(keccak256(abi.encodePacked(
                tx.origin,
                block.coinbase,
                block.basefee,
                block.prevrandao,
                blockhash(currentBlockNum - 1),
                latestExecutionNonce,
                _useNonce(tx.origin)
            )));
            
            if (pseudoRandomNum % 100 <= percentageValue) executionDetails[currentBlockNum].isExecuted == true;
        } else if (antiMEV) {
            // Prevent subsequent transactions of the same trading pair in the current block.
            executionDetails[currentBlockNum].isExecuted == true;
        }

        return true;
    }

    function setPercentageValue(uint256 _percentageValue) external override onlyOwner {
        percentageValue = _percentageValue;
    }


    function setFactory(address factory) external override onlyOwner {
        factories[factory] = true;
    }

    function setAntiFrontBlockEdge(address pair, uint256 antiFrontBlockEdge) external override {
        require(factories[msg.sender], PermissionDenied());
        antiFrontBlockEdges[pair] = antiFrontBlockEdge;
    }
}
