// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface ISolaxy {
    error Prohibited();
    error Undersupply();
    error ZeroAddress();
    error StateExpired();
    error UntransferredDAI();
    error UntransferredSLX();

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

    function estimateMint(uint256 slxAmount) external view returns (uint256);

    function estimateBurn(uint256 slxAmount) external view returns (uint256);
}
