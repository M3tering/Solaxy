// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC6551Account {
    function token() external view returns (uint256 chainId, address tokenContract, uint256 tokenId);
}
