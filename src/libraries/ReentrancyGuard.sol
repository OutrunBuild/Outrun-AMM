// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

/**
 * @dev Outrun's ReentrancyGuard implementation, support transient variable.
 */
abstract contract ReentrancyGuard {
    bool transient locked;

    error ReentrancyGuardReentrantCall();

    modifier nonReentrant() {
        require(!locked, ReentrancyGuardReentrantCall());
        locked = true;
        _;
        locked = false;
    }
}
