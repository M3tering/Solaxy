// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {UD60x18} from "@prb/math/src/UD60x18.sol";

error Prohibited();
error Undersupply();
error CannotBeZero();
error AvertSlippage();
error TransferFailed();

interface ISolaxy is IERC4626 {
    function safeDeposit(
        uint256 assets,
        address receiver,
        uint256 minSharesOut
    ) external returns (uint256 shares);

    function safeWithdraw(
        uint256 assets,
        address receiver,
        address owner,
        uint256 maxSharesIn
    ) external returns (uint256 shares);

    function safeMint(
        uint256 shares,
        address receiver,
        uint256 maxAssetsIn
    ) external returns (uint256 assets);

    function safeRedeem(
        uint256 shares,
        address receiver,
        address owner,
        uint256 minAssetsOut
    ) external returns (uint256 assets);

    function currentPrice() external returns (UD60x18);
}