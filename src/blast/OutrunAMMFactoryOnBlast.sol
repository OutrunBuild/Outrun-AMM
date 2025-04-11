//SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {BlastGovernorable} from "./BlastGovernorable.sol";
import {IMEVGuard} from "../core/interfaces/IMEVGuard.sol";
import {IOutrunAMMFactory} from "../core/interfaces/IOutrunAMMFactory.sol";
import {IOutrunAMMPairOnBlast} from "./interfaces/IOutrunAMMPairOnBlast.sol";

contract OutrunAMMFactoryOnBlast is IOutrunAMMFactory, Ownable, BlastGovernorable {
    address public constant WETH = 0x4200000000000000000000000000000000000023;  // OutrunTODO update on mainnet
    address public constant USDB = 0x4200000000000000000000000000000000000022;  // OutrunTODO update on mainnet

    address public immutable YIELD_VAULT;
    address public immutable pairImplementation;
    uint256 public immutable swapFeeRate;

    address public feeTo;
    address public MEVGuard;
    address[] public allPairs;
    
    mapping(address => mapping(address => address)) public getPair;

    constructor(
        address owner_, 
        address blastGovernor_,
        address yieldVault_,
        address pairImplementation_,
        address MEVGuard_,
        uint256 swapFeeRate_
    ) Ownable(owner_) BlastGovernorable(blastGovernor_) {
        YIELD_VAULT = yieldVault_;
        pairImplementation = pairImplementation_;
        MEVGuard = MEVGuard_;
        swapFeeRate = swapFeeRate_;
    }

    function allPairsLength() external view returns (uint256) {
        return allPairs.length;
    }

    function createPair(address tokenA, address tokenB) external returns (address pair) {
        require(tokenA != tokenB, IdenticalAddresses());

        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), ZeroAddress());
        require(getPair[token0][token1] == address(0), PairExists()); // single check is sufficient

        bytes32 salt = keccak256(abi.encodePacked(token0, token1, swapFeeRate));
        pair = Clones.cloneDeterministic(pairImplementation, salt);
        IOutrunAMMPairOnBlast(pair).initialize(
            token0, 
            token1, 
            blastGovernor, 
            MEVGuard, 
            YIELD_VAULT, 
            swapFeeRate, 
            tokenA == WETH || tokenB == WETH, 
            tokenA == USDB || tokenB == USDB
        );
        IMEVGuard(MEVGuard).setAntiFrontDefendBlockEdge(pair, block.number);
        
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // populate mapping in the reverse direction
        allPairs.push(pair);

        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    function setFeeTo(address _feeTo) external onlyOwner {
        feeTo = _feeTo;
    }

    function setMEVGuard(address _MEVGuard) external override onlyOwner {
        MEVGuard = _MEVGuard;
    }
}