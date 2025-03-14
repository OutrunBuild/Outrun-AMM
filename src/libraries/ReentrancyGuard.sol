// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

/**
 * @dev Outrun's ReentrancyGuard implementation, support transient variable.
 */
abstract contract ReentrancyGuard {
    // evm_version = cancun
    // bool transient locked;
    uint256 private locked = 1;
    error ReentrancyGuardReentrantCall();

    modifier nonReentrant() {
        require(locked == 1, ReentrancyGuardReentrantCall());
        locked = 2;
        _;
        locked = 1;
    }
}
