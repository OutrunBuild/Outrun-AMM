//SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

import {IOutrunAMMERC20} from "./interfaces/IOutrunAMMERC20.sol";

/**
 * @dev OutrunAMM's ERC20 implementation, modified from @solmate implementation
 */
abstract contract OutrunAMMERC20 is IOutrunAMMERC20 {
    string public constant name = "Outrun AMM";

    string public constant symbol = "OUT-AMM";

    uint8 public constant decimals = 18;

    uint256 public totalSupply;

    uint256 public proactivelyBurnedAmount;

    mapping(address => uint256) public balanceOf;

    mapping(address => mapping(address => uint256)) public allowance;

    constructor() {}

    function approve(address spender, uint256 amount) public virtual returns (bool) {
        allowance[msg.sender][spender] = amount;

        emit Approval(msg.sender, spender, amount);

        return true;
    }

    function transfer(address to, uint256 amount) public virtual returns (bool) {
        _beforeTokenTransfer(msg.sender, to, amount);

        if (to == address(0)) proactivelyBurnedAmount += amount;

        balanceOf[msg.sender] -= amount;

        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(msg.sender, to, amount);

        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual returns (bool) {
        _beforeTokenTransfer(from, to, amount);

        uint256 allowed = allowance[from][msg.sender];

        if (allowed != type(uint256).max) allowance[from][msg.sender] = allowed - amount;

        if (to == address(0)) proactivelyBurnedAmount += amount;

        balanceOf[from] -= amount;

        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(from, to, amount);

        return true;
    }

    function _mint(address to, uint256 amount) internal virtual {
        if (to == address(0)) proactivelyBurnedAmount += amount;
        
        totalSupply += amount;

        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal virtual {
        balanceOf[from] -= amount;

        unchecked {
            totalSupply -= amount;
        }

        emit Transfer(from, address(0), amount);
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual {}
}
