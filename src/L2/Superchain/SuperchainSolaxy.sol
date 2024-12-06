// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.24;

import {ERC20, IERC20} from "@openzeppelin/contracts@5.0.2/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts@5.0.2/token/ERC20/extensions/ERC20Burnable.sol";
import {ERC20FlashMint} from "@openzeppelin/contracts@5.0.2/token/ERC20/extensions/ERC20FlashMint.sol";
import {ERC20Permit} from "@openzeppelin/contracts@5.0.2/token/ERC20/extensions/ERC20Permit.sol";

import {IERC7802, IERC165} from "../../interfaces/IERC7802.sol";

/**
 * @title SuperchainSolaxy
 * @notice A standard ERC20 extension implementing IERC7802 for unified cross-chain fungibility across
 * the Superchain. Allows the SuperchainTokenBridge to mint and burn tokens as needed.
 */
contract SuperchainSolaxy is IERC7802, ERC20, ERC20Burnable, ERC20Permit, ERC20FlashMint {
    address public constant SUPERCHAIN_TOKEN_BRIDGE = 0x4200000000000000000000000000000000000028;

    error Unauthorized();

    constructor() ERC20("Solaxy", "SOLX") ERC20Permit("Solaxy") {}

    function crosschainMint(address _to, uint256 _amount) external {
        if (msg.sender != SUPERCHAIN_TOKEN_BRIDGE) revert Unauthorized();
        _mint(_to, _amount);
        emit CrosschainMint(_to, _amount, msg.sender);
    }

    function crosschainBurn(address _from, uint256 _amount) external {
        if (msg.sender != SUPERCHAIN_TOKEN_BRIDGE) revert Unauthorized();
        _burn(_from, _amount);
        emit CrosschainBurn(_from, _amount, msg.sender);
    }

    /**
     * @notice Query if a contract implements an interface
     * @param _interfaceId The interface identifier, as specified in ERC-165
     * @dev Interface identification is specified in ERC-165. This function
     * uses less than 30,000 gas.
     * @return `true` if the contract implements `_interfaceId` and
     * `_interfaceId` is not 0xffffffff, `false` otherwise
     */
    function supportsInterface(bytes4 _interfaceId) public view virtual returns (bool) {
        return _interfaceId == type(IERC7802).interfaceId || _interfaceId == type(IERC20).interfaceId
            || _interfaceId == type(IERC165).interfaceId;
    }
}
