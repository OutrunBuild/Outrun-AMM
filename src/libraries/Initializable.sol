// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

abstract contract Initializable {
    bool public initialized;
    bool public initializing;

    error NotInitializing();
    error InvalidInitialization();

    modifier initializer() {
        require(!initialized, InvalidInitialization());

        initialized = true;
        initializing = true;
        _;
        initializing = false;
    }

    modifier onlyInitializing() {
        _checkInitializing();
        _;
    }

    function _checkInitializing() internal view {
        if (!initializing) {
            revert NotInitializing();
        }
    }
}
