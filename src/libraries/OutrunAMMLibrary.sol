//SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

import {IOutrunAMMFactory} from "../core/interfaces/IOutrunAMMFactory.sol";

library OutrunAMMLibrary {
    /**
     * @notice Zero address.
     */
    error ZeroAddress();

    /**
     * @notice Identical addresses.
     */
    error IdenticalAddresses();

    /**
     * @notice Sort the tokens.
     * @param tokenA - The first token address.
     * @param tokenB - The second token address.
     * @return token0 - The first token address.
     * @return token1 - The second token address.
     */
    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        require(tokenA != tokenB, IdenticalAddresses());
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), ZeroAddress());
    }

    /**
     * @notice Calculate the pair address.
     * @param factory - The factory address.
     * @param tokenA - The first token address.
     * @param tokenB - The second token address.
     * @param swapFeeRate - The swap fee rate.
     * @return pair - The pair address.
     */
    function pairFor(address factory, address tokenA, address tokenB, uint256 swapFeeRate) internal view returns (address pair) {
        (address token0, address token1) = sortTokens(tokenA, tokenB);

        pair = Clones.predictDeterministicAddress(
            IOutrunAMMFactory(factory).pairImplementation(),
            keccak256(abi.encodePacked(token0, token1, swapFeeRate)),
            factory
        );
    }
}
