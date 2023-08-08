// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

interface GitcoinScorer {
    function scorePassport(
        address recipient
    ) external view returns (uint256 score);
}
