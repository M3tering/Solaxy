// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC4626View} from "../interfaces/IERC4626View.sol";

interface ISolaxyView is IERC4626View {
    error Undersupply();
    error Unauthorized();
    error CannotBeZero();

    function currentPrice() external view returns (uint256);
}
