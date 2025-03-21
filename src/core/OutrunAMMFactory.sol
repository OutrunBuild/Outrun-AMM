//SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {IOutrunAMMPair, OutrunAMMPair} from "./OutrunAMMPair.sol";
import {IOutrunAMMFactory} from "./interfaces/IOutrunAMMFactory.sol";
import {IFairModeExecutor} from "./interfaces/IFairModeExecutor.sol";

contract OutrunAMMFactory is IOutrunAMMFactory, Ownable {
    uint256 public immutable swapFeeRate;
    address public immutable pairImplementation;
    address public immutable fairModeExecutor;

    address public feeTo;
    address[] public allPairs;
    
    mapping(address => mapping(address => address)) public getPair;

    constructor(
        address owner_, 
        address pairImplementation_, 
        address fairModeExecutor_,
        uint256 swapFeeRate_
    ) Ownable(owner_) {
        swapFeeRate = swapFeeRate_;
        pairImplementation = pairImplementation_;
        fairModeExecutor = fairModeExecutor_;
    }

    function allPairsLength() external view returns (uint256) {
        return allPairs.length;
    }

    function createPair(address tokenA, address tokenB, bool fairMode, uint256 fairBlockCount) external returns (address pair) {
        require(tokenA != tokenB, IdenticalAddresses());
        if(fairMode) require(fairBlockCount >= 200, ShortDuration());

        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), ZeroAddress());
        require(getPair[token0][token1] == address(0), PairExists()); // single check is sufficient

        bytes32 salt = keccak256(abi.encodePacked(token0, token1, swapFeeRate));
        pair = Clones.cloneDeterministic(pairImplementation, salt);
        IOutrunAMMPair(pair).initialize(token0, token1, fairModeExecutor, swapFeeRate, block.number + fairBlockCount, fairMode);
        if(fairMode) IFairModeExecutor(fairModeExecutor).setFairPair(pair);
        
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // populate mapping in the reverse direction
        allPairs.push(pair);

        emit PairCreated(token0, token1, pair, allPairs.length, fairMode, fairBlockCount);
    }

    function setFeeTo(address _feeTo) external onlyOwner {
        feeTo = _feeTo;
    }
}