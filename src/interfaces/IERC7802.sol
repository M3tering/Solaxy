// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC165} from "@openzeppelin/contracts@5.0.2/interfaces/IERC165.sol";

/// @title IERC7802
/// @notice Defines the interface for crosschain ERC20 transfers.
interface IERC7802 is IERC165 {
    event CrosschainMint(address indexed to, uint256 amount, address indexed sender);

    event CrosschainBurn(address indexed from, uint256 amount, address indexed sender);

    function crosschainMint(address _to, uint256 _amount) external;

    function crosschainBurn(address _from, uint256 _amount) external;
}
