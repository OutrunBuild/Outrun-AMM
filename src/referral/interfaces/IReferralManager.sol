//SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

interface IReferralManager {
    function referrerOf(address account) external view returns (address referrer);

    function registerReferrer(address account, address referrer) external;

    error ZeroAddress();

    error AlreadyRegister();

    event RegisterReferrer(address indexed account, address indexed referrer);
}
