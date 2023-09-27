// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./interfaces/ISolaxy.sol";
import "./XRC20.sol";

contract Solaxy is ISolaxy, XRC20 {
    ERC20 public constant DAI = ERC20(0x1CbAd85Aa66Ff3C12dc84C5881886EEB29C1bb9b);
    address public feeAddress;

    constructor() ERC20("Solaxy", "SLX") ERC20Permit("Solaxy") {
        if (address(DAI) == address(0)) revert ZeroAddress();
        feeAddress = msg.sender;
    }

    receive() external payable {
        revert Prohibited();
    }

    function mint(uint256 slxAmount, uint256 daiAmountInMin) external {
        uint256 daiAmountIn = estimateMint(slxAmount);
        if (daiAmountIn > daiAmountInMin) revert AvertSlippage();

        if (!DAI.transferFrom(msg.sender, address(this), daiAmountIn)) revert UntransferredDAI();
        emit Mint(slxAmount, daiAmountIn, DAI.balanceOf(address(this)), block.timestamp);

        _mint(msg.sender, slxAmount);
    }

    function burn(uint256 slxAmount, uint256 daiAmountOutMax) external {
        (uint256 daiAmountOut, uint256 burnAmount, uint256 fee) = _estimateBurn(slxAmount);
        if (daiAmountOut < daiAmountOutMax) revert AvertSlippage();

        _burn(msg.sender, burnAmount);

        if (!transfer(feeAddress, fee)) revert UntransferredSLX();
        if (!DAI.transfer(msg.sender, daiAmountOut)) revert UntransferredDAI();
        emit Burn(burnAmount, daiAmountOut, DAI.balanceOf(address(this)), block.timestamp);
    }

    function currentPrice() external view returns (uint256) {
        return _price(totalSupply());
    }

    function estimateMint(uint256 slxAmount) public view returns (uint256 daiAmountIn) {
        uint256 initalSupply = totalSupply();
        uint256 finalSupply = initalSupply + slxAmount;

        return _collateral(slxAmount, initalSupply, finalSupply, decimals());
    }

    function estimateBurn(uint256 slxAmount) public view returns (uint256 daiAmountOut) {
        (daiAmountOut, , ) = _estimateBurn(slxAmount);
        return daiAmountOut;
    }

    function _estimateBurn(
        uint256 slxAmount
    ) internal view returns (uint256 daiAmountOut, uint256 burnAmount, uint256 fee) {
        uint256 initalSupply = totalSupply();
        if (initalSupply < slxAmount) revert Undersupply();

        fee = (slxAmount * 264) / 1000;
        burnAmount = slxAmount - fee;
        uint256 finalSupply = initalSupply - burnAmount;

        daiAmountOut = _collateral(burnAmount, initalSupply, finalSupply, decimals());
        return (daiAmountOut, burnAmount, fee);
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
