// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

import {BlastModeEnum} from "./BlastModeEnum.sol";

interface IERC20Rebasing is BlastModeEnum {
    function configure(YieldMode) external returns (uint256);

    function claim(address recipient,uint256 amount) external returns (uint256);

    function getClaimableAmount(address account) external view returns (uint256);
}