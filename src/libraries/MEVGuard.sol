//SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

import {Initializable} from "../libraries/Initializable.sol";

/**
 * @dev MEV Guard - Anti-Front Running and MEV
 */
abstract contract MEVGuard is Initializable {
    uint256 public antiFrontBlockEdge;

    uint256 public antiFrontPercentage;

    uint256 private nonce;

    mapping(uint256 blockNum => bool) private executionStates;

    function __OutrunMEVGuard_init(uint256 _antiFrontBlockEdge, uint256 _antiFrontPercentage) internal onlyInitializing {
        antiFrontBlockEdge = _antiFrontBlockEdge;
        antiFrontPercentage = _antiFrontPercentage;
    }

    function _MEVDefend(
        bool antiMEV,
        uint256 reserve0, 
        uint256 reserve1,
        uint256 amount0Out,
        uint256 amount1Out
    ) internal returns (bool) {
        uint256 currentBlockNum = block.number;

        // Only one transaction can succeed per block before antiFrontBlockEdge, or the previous 
        // successful transaction did not enable anti-MEV.
        if (executionStates[currentBlockNum]) return false;

        // Anti-Front Running
        if (currentBlockNum < antiFrontBlockEdge) {
            uint256 _nonce = nonce + 1;
            nonce = _nonce;

            // Each transaction can purchase a maximum of 1% of the tokens in the liquidity pool
            // before antiFrontBlockEdge.
            if (amount0Out * 100 >  reserve0 || amount1Out * 100 > reserve1) return false;

            // Integrating VRF into the Swap process significantly degrades the user experience. 
            // Pseudorandom numbers are already sufficient, but using VRF instead makes it cheaper 
            // for attackers, as they can conduct transactions with multiple addresses and avoid 
            // gas bidding.
            uint256 pseudoRandomNum = uint256(keccak256(abi.encodePacked(
                tx.origin,
                block.coinbase,
                block.basefee,
                block.prevrandao,
                blockhash(currentBlockNum - 1),
                _nonce
            )));
            
            // Success probability is antiFrontPercentage%
            if (pseudoRandomNum % 100 <= antiFrontPercentage) {
                executionStates[currentBlockNum] = true;
            } else {
                return false;
            }
        } else if (antiMEV) {
            // Prevent subsequent transactions of the same trading pair in the current block.
            executionStates[currentBlockNum] = true;
        }
        return true;
    }
}
