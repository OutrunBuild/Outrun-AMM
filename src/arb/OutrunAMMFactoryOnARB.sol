//SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {IArbSys} from "./IArbSys.sol";
import {IMEVGuard} from "../core/interfaces/IMEVGuard.sol";
import {IOutrunAMMPair} from "../core/interfaces/IOutrunAMMPair.sol";
import {IOutrunAMMFactory} from "../core/interfaces/IOutrunAMMFactory.sol";

contract OutrunAMMFactoryOnARB is IOutrunAMMFactory, Ownable {
    address public constant arbSys = 0x0000000000000000000000000000000000000064;

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

    function createPair(address tokenA, address tokenB) external override returns (address pair) {
        require(tokenA != tokenB, IdenticalAddresses());

        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), ZeroAddress());
        require(getPair[token0][token1] == address(0), PairExists()); // single check is sufficient

        bytes32 salt = keccak256(abi.encodePacked(token0, token1, swapFeeRate));
        pair = Clones.cloneDeterministic(pairImplementation, salt);
        IOutrunAMMPair(pair).initialize(token0, token1, MEVGuard, swapFeeRate);
        IMEVGuard(MEVGuard).setAntiFrontDefendBlockEdge(pair, IArbSys(arbSys).arbBlockNumber());
        
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