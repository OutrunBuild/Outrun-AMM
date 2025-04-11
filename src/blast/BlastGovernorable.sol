// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

import { IBlast } from "./IBlast.sol";
import { BlastModeEnum } from "./BlastModeEnum.sol";

interface IBlastGovernorable is BlastModeEnum  {
    function configure(YieldMode yieldMode, GasMode gasMode) external;

    function readGasBalance() external view returns (uint256);

    function claimMaxGas(address recipient) external returns (uint256 gasAmount);

    function transferGasManager(address newBlastGovernor) external;
}

abstract contract BlastGovernorable is IBlastGovernorable {
    IBlast public constant BLAST = IBlast(0x4300000000000000000000000000000000000002);  // OutrunTODO update on mainnet

    address public blastGovernor;

    error BlastZeroAddress();

    error UnauthorizedAccount(address account);

    event ClaimMaxGas(address indexed recipient, uint256 gasAmount);

    event BlastGovernorTransferred(address indexed previousBlastGovernor, address indexed newBlastGovernor);

    constructor(address initialBlastGovernor) {
        require(initialBlastGovernor != address(0), BlastZeroAddress());
        blastGovernor = initialBlastGovernor;
    }

    modifier onlyBlastGovernor() {
        address msgSender = msg.sender;
        require(blastGovernor == msgSender, UnauthorizedAccount(msgSender));
        _;
    }

    function configure(YieldMode yieldMode, GasMode gasMode) external override onlyBlastGovernor {
        BLAST.configure(yieldMode, gasMode, blastGovernor);
    }

    /**
     * @dev Read all gas remaining balance 
     */
    function readGasBalance() external view override onlyBlastGovernor returns (uint256) {
        (, uint256 gasBalance, , ) = BLAST.readGasParams(address(this));
        return gasBalance;
    }

    /**
     * @dev Claim max gas of this contract
     * @param recipient - Address of receive gas
     */
    function claimMaxGas(address recipient) external override onlyBlastGovernor returns (uint256 gasAmount) {
        require(recipient != address(0), BlastZeroAddress());

        gasAmount = BLAST.claimMaxGas(address(this), recipient);
        emit ClaimMaxGas(recipient, gasAmount);
    }

    function transferGasManager(address newBlastGovernor) external override onlyBlastGovernor {
        require(newBlastGovernor != address(0), BlastZeroAddress());

        _transferBlastGovernor(newBlastGovernor);
    }

    function _transferBlastGovernor(address newBlastGovernor) internal {
        address oldBlastGovernor = blastGovernor;
        blastGovernor = newBlastGovernor;
        BLAST.configure(YieldMode.VOID, GasMode.CLAIMABLE, newBlastGovernor);

        emit BlastGovernorTransferred(oldBlastGovernor, newBlastGovernor);
    }
}