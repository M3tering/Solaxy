// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {UD60x18} from "@prb/math/src/UD60x18.sol";

import "./interfaces/ISolaxy.sol";
import "./XRC20.sol";

contract Solaxy is ISolaxy, XRC20 {
    ERC20 public constant DAI =
        ERC20(0x1CbAd85Aa66Ff3C12dc84C5881886EEB29C1bb9b);
    UD60x18 public constant slope = UD60x18.wrap(0.0025e18);
    UD60x18 public constant _2e18 = UD60x18.wrap(2e18);
    address public immutable feeAddress;

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

        if (!DAI.transferFrom(msg.sender, address(this), daiAmountIn))
            revert UntransferredDAI();
        emit Mint(
            slxAmount,
            daiAmountIn,
            DAI.balanceOf(address(this)),
            block.timestamp
        );

        _mint(msg.sender, slxAmount);
    }

    function burn(uint256 slxAmount, uint256 daiAmountOutMax) external {
        (uint256 daiAmountOut, uint256 burnAmount, uint256 fee) = _estimateBurn(
            slxAmount
        );
        if (daiAmountOut < daiAmountOutMax) revert AvertSlippage();

        _burn(msg.sender, burnAmount);

        if (!transfer(feeAddress, fee)) revert UntransferredSLX();
        if (!DAI.transfer(msg.sender, daiAmountOut)) revert UntransferredDAI();
        emit Burn(
            burnAmount,
            daiAmountOut,
            DAI.balanceOf(address(this)),
            block.timestamp
        );
    }

    function currentPrice() external view returns (uint256) {
        return _price(UD60x18.wrap(totalSupply())).intoUint256();
    }

    function estimateMint(
        uint256 slxAmount
    ) public view returns (uint256 daiAmountIn) {
        uint256 initalSupply = totalSupply();
        uint256 finalSupply = initalSupply + slxAmount;

        return
            _collateral(
                UD60x18.wrap(slxAmount),
                UD60x18.wrap(initalSupply),
                UD60x18.wrap(finalSupply)
            ).intoUint256();
    }

    function estimateBurn(
        uint256 slxAmount
    ) public view returns (uint256 daiAmountOut) {
        (daiAmountOut, , ) = _estimateBurn(slxAmount);
        return daiAmountOut;
    }

    function _estimateBurn(
        uint256 slxAmount
    )
        internal
        view
        returns (uint256 daiAmountOut, uint256 burnAmount, uint256 fee)
    {
        uint256 initalSupply = totalSupply();
        if (initalSupply < slxAmount) revert Undersupply();

        fee = (slxAmount * 264) / 1000;
        burnAmount = slxAmount - fee;
        uint256 finalSupply = initalSupply - burnAmount;

        daiAmountOut = _collateral(
            UD60x18.wrap(burnAmount),
            UD60x18.wrap(initalSupply),
            UD60x18.wrap(finalSupply)
        ).intoUint256();
        return (daiAmountOut, burnAmount, fee);
    }

    function _collateral(
        UD60x18 slxAmount,
        UD60x18 initalSupply,
        UD60x18 finalSupply
    ) internal pure returns (UD60x18) {
        // area under a liner function == area of trapezoid
        // A = h * (a + b) / 2; where a = f(x) and h is slxAmount

        UD60x18 sumPrice = _price(initalSupply).add(_price(finalSupply));
        return sumPrice.mul(slxAmount).div(_2e18);
    }

    function _amount(
        UD60x18 initalSupply,
        UD60x18 collateral
    ) internal pure returns (UD60x18) {
        // y = sqrt((A + 0.00125x^2) / 0.00125)
        // y = sqrt((0.00125x^2 - A) / 0.00125)
        // x = sqrt((2A + 0.0025y^2) / 0.0025)

        UD60x18 d = initalSupply.powu(2).mul(slope);
        UD60x18 e = collateral.mul(_2e18).add(d);
        return e.div(slope).sqrt() - initalSupply;
    }

    function _price(UD60x18 tokenSupply) internal pure returns (UD60x18) {
        // a linear price function;
        // f(x) = mx + b; where b = 0 and m = 0.0025

        return tokenSupply.mul(slope);
    }
}
