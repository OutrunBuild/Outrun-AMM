//SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {IArbSys} from "../arb/IArbSys.sol";
import {IMEVGuard} from "../core/interfaces/IMEVGuard.sol";
import {IOutrunAMMFactory} from "../core/interfaces/IOutrunAMMFactory.sol";

/**
 * @dev MEV Guard - Anti-Front Running and MEV
 */
contract MEVGuardOnARB is IMEVGuard, Ownable {
    uint256 public constant RATIO = 10000;
    address public constant arbSys = 0x0000000000000000000000000000000000000064;

    uint256 public antiFrontDefendBlock;

    address public transient originTo;

    mapping(address factory => bool) public factories;

    mapping(address pair => uint256) public antiFrontDefendBlockEdges;

    mapping(uint256 blockNum => ExecutionDetail) private executionDetails;

    mapping(uint256 blockNum => mapping(address pair => mapping(address origin => bool))) private uniqueRequests;

    constructor(address _owner, uint256 _antiFrontDefendBlock) Ownable(_owner) {
        antiFrontDefendBlock = _antiFrontDefendBlock;
    }

    function defend(
        uint256 reserve0, 
        uint256 reserve1,
        uint256 amount0Out,
        uint256 amount1Out
    ) external override returns (bool) {
        uint256 antiFrontDefendBlockEdge = antiFrontDefendBlockEdges[msg.sender];
        require(antiFrontDefendBlockEdge != 0, PermissionDenied());

        uint256 currentBlockNum = IArbSys(arbSys).arbBlockNumber();

        uint256 _currentExecutionRequestNum = ++executionDetails[currentBlockNum].requestNum;
        
        // Anti-Front Running
        if (currentBlockNum < antiFrontDefendBlockEdge) {
            if (uniqueRequests[currentBlockNum][msg.sender][tx.origin]) return false;
            uniqueRequests[currentBlockNum][msg.sender][tx.origin] = true;

            // Only one transaction can succeed per block before antiFrontBlockEdge
            if (executionDetails[currentBlockNum].isExecuted) return false;

            // Each transaction can purchase a maximum of 1% of the tokens in the liquidity pool
            // before antiFrontBlockEdge.
            if (amount0Out * 200 > reserve0 || amount1Out * 200 > reserve1) return false;

            // Integrating VRF into the Swap process significantly degrades the user experience. 
            // Pseudorandom numbers are already sufficient, but using VRF instead makes it cheaper 
            // for attackers, as they can conduct transactions with multiple addresses and avoid 
            // gas bidding.
            uint256 latestExecutionRequestNum = executionDetails[currentBlockNum - 1].requestNum;
            uint256 randomNum = uint256(keccak256(abi.encodePacked(
                tx.origin,
                block.coinbase,
                block.basefee,
                block.prevrandao,
                IArbSys(arbSys).arbBlockHash(currentBlockNum - 1),
                gasleft(),
                latestExecutionRequestNum,
                _currentExecutionRequestNum
            )));
            
            // Success probability is 1 / denominator
            uint256 denominator = latestExecutionRequestNum == 0 ? 1 : latestExecutionRequestNum;
            if (randomNum % denominator == 0) {
                executionDetails[currentBlockNum].isExecuted == true;
            } else {
                return false;
            }
        }

        return true;
    }

    function setOriginTo(address _originTo) external override {
        originTo = _originTo;
    }

    function setFactoryStatus(address factory, bool status) external override onlyOwner {
        factories[factory] = status;
    }

    function setAntiFrontDefendBlockEdge(address pair, uint256 startBlockNum) external override {
        require(factories[msg.sender], PermissionDenied());
        antiFrontDefendBlockEdges[pair] = startBlockNum + antiFrontDefendBlock;
    }

    function setAntiFrontDefendBlock(uint256 _antiFrontDefendBlock) external override onlyOwner {
        antiFrontDefendBlock = _antiFrontDefendBlock;
    }
}