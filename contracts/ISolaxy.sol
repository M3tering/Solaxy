// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface ISolaxy {
    error DaiError();
    error Prohibited();
    error Undersupply();
    error StateExpired();

    event Mint(
        uint256 indexed slxAmount,
        uint256 indexed daiAmount,
        uint256 indexed daiBalance,
        uint256 timestamp
    );

    event Burn(
        uint256 indexed slxAmount,
        uint256 indexed daiAmount,
        uint256 indexed daiBalance,
        uint256 timestamp
    );

    function mint(uint256 slxAmount, uint256 mintId) external;

    function burn(uint256 slxAmount, uint256 burnId) external;

    function currentPrice() external view returns (uint256);

    function costToMint(uint256 slxAmount) external view returns (uint256);

    function refundOnBurn(uint256 slxAmount) external view returns (uint256);
}
