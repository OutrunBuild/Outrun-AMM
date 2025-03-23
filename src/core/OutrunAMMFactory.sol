//SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {IOutrunAMMPair, OutrunAMMPair} from "./OutrunAMMPair.sol";
import {IOutrunAMMFactory} from "./interfaces/IOutrunAMMFactory.sol";

contract OutrunAMMFactory is IOutrunAMMFactory, Ownable {
    uint256 public immutable swapFeeRate;
    address public immutable pairImplementation;

    address public feeTo;
    address[] public allPairs;
    uint256 public antiFrontBlock;
    uint256 public antiFrontPercentage;
    uint256 public MEVGuardFeePercentage;
    
    mapping(address => mapping(address => address)) public getPair;

    constructor(
        address owner_, 
        address pairImplementation_,
        uint256 swapFeeRate_,
        uint256 antiFrontBlock_,
        uint256 antiFrontPercentage_,
        uint256 MEVGuardFeePercentage_
    ) Ownable(owner_) {
        swapFeeRate = swapFeeRate_;
        pairImplementation = pairImplementation_;
        antiFrontBlock = antiFrontBlock_;
        antiFrontPercentage = antiFrontPercentage_;
        MEVGuardFeePercentage = MEVGuardFeePercentage_;
    }

    function allPairsLength() external view override returns (uint256) {
        return allPairs.length;
    }

    function createPair(address tokenA, address tokenB) external override returns (address pair) {
        require(tokenA != tokenB, IdenticalAddresses());

        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), ZeroAddress());
        require(getPair[token0][token1] == address(0), PairExists()); // single check is sufficient

        bytes32 salt = keccak256(abi.encodePacked(token0, token1, swapFeeRate));
        pair = Clones.cloneDeterministic(pairImplementation, salt);
        IOutrunAMMPair(pair).initialize(token0, token1, swapFeeRate, block.number + antiFrontBlock, antiFrontPercentage);
        
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // populate mapping in the reverse direction
        allPairs.push(pair);

        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    function setFeeTo(address _feeTo) external override onlyOwner {
        feeTo = _feeTo;
    }

    function setAntiFrontBlock(uint256 _antiFrontBlock) external override onlyOwner {
        antiFrontBlock = _antiFrontBlock;
    }

    function setAntiFrontPercentage(uint256 _antiFrontPercentage) external override onlyOwner {
        antiFrontPercentage = _antiFrontPercentage;
    }

    function setMEVGuardFeePercentage(uint256 _MEVGuardFeePercentage) external override onlyOwner {
        MEVGuardFeePercentage = _MEVGuardFeePercentage;
    }
}