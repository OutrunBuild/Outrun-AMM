//SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {IReferralManager} from "./interfaces/IReferralManager.sol";

/**
 * @dev OutSwap Referrer Manager
 */
contract ReferralManager is IReferralManager, Ownable {
    mapping(address account => address) private _referrers;

    constructor(address owner) Ownable(owner) {}

    function referrerOf(address account) external view override returns (address) {
        return _referrers[account];
    }

    function registerReferrer(address account, address referrer) external override onlyOwner {
        require(account != address(0) && referrer != address(0), ZeroAddress());
        require(_referrers[account] == address(0), AlreadyRegister());

        _referrers[account] = referrer;

        emit RegisterReferrer(account, referrer);
    }
}
