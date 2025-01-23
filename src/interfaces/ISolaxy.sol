// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC4626} from "@openzeppelin/contracts@5.2.0/interfaces/IERC4626.sol";

interface ISolaxy is IERC4626 {
    error Undersupply();
    error CannotBeZero();
    error SlippageError();
    error TransferError();
    error RequiresM3ter();

    function safeDeposit(uint256 assets, address receiver, uint256 minSharesOut) external returns (uint256 shares);

    function safeWithdraw(uint256 assets, address receiver, address owner, uint256 maxSharesIn)
        external
        returns (uint256 shares);

    function safeMint(uint256 shares, address receiver, uint256 maxAssetsIn) external returns (uint256 assets);

    function safeRedeem(uint256 shares, address receiver, address owner, uint256 minAssetsOut)
        external
        returns (uint256 assets);

    function currentPrice() external returns (uint256);

    function tipAccount() external returns (address);
}
