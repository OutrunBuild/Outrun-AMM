//SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {IMEVGuard} from "./interfaces/IMEVGuard.sol";
import {IOutrunAMMPair} from "./interfaces/IOutrunAMMPair.sol";
import {IOutrunAMMFactory} from "./interfaces/IOutrunAMMFactory.sol";

contract OutrunAMMFactory is IOutrunAMMFactory, Ownable {
    uint256 public immutable swapFeeRate;
    address public immutable pairImplementation;
    
    address public feeTo;
    address public MEVGuard;
    address[] public allPairs;

    mapping(address => mapping(address => address)) public getPair;

    constructor(
        address owner_, 
        address pairImplementation_,
        address MEVGuard_,
        uint256 swapFeeRate_
    ) Ownable(owner_) {
        swapFeeRate = swapFeeRate_;
        pairImplementation = pairImplementation_;
        MEVGuard = MEVGuard_;
    }

    function allPairsLength() external view override returns (uint256) {
        return allPairs.length;
    }

    /**
     * @param triggerTime - For POL(FFLaunch/Memeverse) liquidity protection period, If it is 0, it means there is no POL liquidity protection period
     */
    function createPair(address tokenA, address tokenB, uint256 triggerTime) external override returns (address pair) {
        require(tokenA != tokenB, IdenticalAddresses());

        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), ZeroAddress());
        require(getPair[token0][token1] == address(0), PairExists()); // single check is sufficient

        bytes32 salt = keccak256(abi.encodePacked(token0, token1, swapFeeRate));
        pair = Clones.cloneDeterministic(pairImplementation, salt);
        IOutrunAMMPair(pair).initialize(token0, token1, MEVGuard, swapFeeRate, triggerTime);
        IMEVGuard(MEVGuard).setAntiFrontDefendBlockEdge(pair, block.number);
        
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // populate mapping in the reverse direction
        allPairs.push(pair);

        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    function setFeeTo(address _feeTo) external override onlyOwner {
        feeTo = _feeTo;
    }

    function setMEVGuard(address _MEVGuard) external override onlyOwner {
        MEVGuard = _MEVGuard;
    }
}