// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC6551Registry {
    function account(address implementation, bytes32 salt, uint256 chainId, address tokenContract, uint256 tokenId)
        external
        view
        returns (address account);
}
