// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface ISolaxy {
    error Prohibited();
    error DaiError();

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

    function costToMint(uint256 amount) external view returns (uint256);

    function refundOnBurn(uint256 amount) external view returns (uint256);

    function mint(uint256 slxAmount) external;

    function burn(uint256 slxAmount) external;
}
