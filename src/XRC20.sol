// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts@4.9.3/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts@4.9.3/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts@4.9.3/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts@4.9.3/token/ERC20/extensions/ERC20FlashMint.sol";

abstract contract XRC20 is ERC20, ERC20Permit, ERC20Votes, ERC20FlashMint {
    // The following functions are overrides required by Solidity.

    function _afterTokenTransfer(address from, address to, uint256 amount) internal override(ERC20, ERC20Votes) {
        super._afterTokenTransfer(from, to, amount);
    }

    function _mint(address to, uint256 amount) internal override(ERC20, ERC20Votes) {
        super._mint(to, amount);
    }

    function _burn(address account, uint256 amount) internal override(ERC20, ERC20Votes) {
        super._burn(account, amount);
    }
}
