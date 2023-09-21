// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./XRC20.sol";
import "./ISolaxy.sol";

contract Solaxy is ISolaxy, XRC20 {
    ERC20 public constant DAI = ERC20(0x1CbAd85Aa66Ff3C12dc84C5881886EEB29C1bb9b);
    address public feeAddress;
    uint256 public mintID;
    uint256 public burnID;

    constructor() ERC20("Solaxy", "SLX") ERC20Permit("Solaxy") {
        if (address(DAI) == address(0)) revert ZeroAddress();
        feeAddress = msg.sender;
    }

    receive() external payable {
        revert Prohibited();
    }

    function mint(uint256 slxAmount, uint256 mintId) external {
        if (mintId < mintID++) revert StateExpired();
        uint256 daiAmount = estimateMint(slxAmount);

        if (!DAI.transferFrom(msg.sender, address(this), daiAmount)) revert UntransferredDAI();
        emit Mint(slxAmount, daiAmount, DAI.balanceOf(address(this)), block.timestamp);

        _mint(msg.sender, slxAmount);
    }

    function burn(uint256 slxAmount, uint256 burnId) external {
        if (burnId < burnID++) revert StateExpired();
        (uint256 daiAmount, uint256 burnAmount, uint256 fee) = _estimateBurn(slxAmount);

        _burn(msg.sender, burnAmount);

        if (!transfer(feeAddress, fee)) revert UntransferredSLX();
        if (!DAI.transfer(msg.sender, daiAmount)) revert UntransferredDAI();
        emit Burn(burnAmount, daiAmount, DAI.balanceOf(address(this)), block.timestamp);
    }

    function currentPrice() external view returns (uint256) {
        return _price(totalSupply());
    }

    function estimateMint(uint256 slxAmount) public view returns (uint256 daiAmount) {
        uint256 initalSupply = totalSupply();
        uint256 finalSupply = initalSupply + slxAmount;

        daiAmount = _collateral(slxAmount, initalSupply, finalSupply, decimals());
        return daiAmount;
    }

    function estimateBurn(uint256 slxAmount) public view returns (uint256 daiAmount) {
        (daiAmount, , ) = _estimateBurn(slxAmount);
        return daiAmount;
    }

    function _estimateBurn(
        uint256 slxAmount
    ) internal view returns (uint256 daiAmount, uint256 burnAmount, uint256 fee) {
        uint256 initalSupply = totalSupply();
        if (initalSupply < slxAmount) revert Undersupply();

        fee = (slxAmount * 264) / 1000;
        burnAmount = slxAmount - fee;
        uint256 finalSupply = initalSupply - burnAmount;

        daiAmount = _collateral(burnAmount, initalSupply, finalSupply, decimals());
        return (daiAmount, burnAmount, fee);
    }

    function _collateral(
        uint256 slxAmount,
        uint256 initalSupply,
        uint256 finalSupply,
        uint256 decimals
    ) internal pure returns (uint256) {
        // area under a liner function == area of trapezoid
        // A = h * (a + b) / 2; where a = f(x) and h is slxAmount

        uint256 a = _price(initalSupply);
        uint256 b = _price(finalSupply);

        return (slxAmount * (a + b)) / (2 * 10 ** decimals);
    }

    function _price(uint256 tokenSupply) internal pure returns (uint256) {
        // a linear price function;
        // f(x) = mx + b; where b = 0 and m = 0.0025

        return (tokenSupply * 25) / 10_000;
    }
}
