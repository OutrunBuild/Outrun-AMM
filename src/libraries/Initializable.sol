// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

abstract contract Initializable {
    bool public initialized;

    error InvalidInitialization();

    modifier initializer() {
        require(!initialized, InvalidInitialization());

        initialized = true;
        _;
    }
}
