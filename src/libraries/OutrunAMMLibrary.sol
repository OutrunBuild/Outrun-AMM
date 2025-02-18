//SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

import {IOutrunAMMPair} from "../core/interfaces/IOutrunAMMPair.sol";
import {IOutrunAMMFactory} from "../core/interfaces/IOutrunAMMFactory.sol";


library OutrunAMMLibrary {
    uint256 internal constant RATIO = 10000;
    
    error ZeroAddress();

    error IdenticalAddresses();

    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        require(tokenA != tokenB, IdenticalAddresses());
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), ZeroAddress());
    }

    function pairFor(address factory, address tokenA, address tokenB, uint256 swapFeeRate) internal view returns (address pair) {
        (address token0, address token1) = sortTokens(tokenA, tokenB);

        pair = Clones.predictDeterministicAddress(
            IOutrunAMMFactory(factory).pairImplementation(),
            keccak256(abi.encodePacked(token0, token1, swapFeeRate)),
            factory
        );
    }
}
