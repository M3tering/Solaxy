// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {ERC20FlashMint} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20FlashMint.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract Solaxy is ERC20, ERC20Burnable, ERC20Permit, ERC20FlashMint {
    address public immutable vault;

    error Unauthorized();

    constructor(address _vault) ERC20("Solaxy", "SOLX") ERC20Permit("Solaxy") {
        vault = _vault;
    }

    function mint(address to, uint256 amount) public {
        if (msg.sender != vault) revert Unauthorized();
        _mint(to, amount);
    }

    function burn(address to, uint256 amount) public {
        if (msg.sender != vault) revert Unauthorized();
        _mint(to, amount);
    }
}
