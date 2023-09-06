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
        feeAddress = msg.sender;
    }

    receive() external payable {
        revert Prohibited();
    }

    function mint(uint256 slxAmount, uint256 mintId) external {
        if (mintId < mintID++) revert StateExpired();
        uint256 daiAmount = costToMint(slxAmount);
        if (!DAI.transferFrom(msg.sender, address(this), daiAmount)) revert DaiError();
        emit Mint(slxAmount, daiAmount, DAI.balanceOf(address(this)), block.timestamp);
        _mint(msg.sender, slxAmount);
    }

    function burn(uint256 slxAmount, uint256 burnId) external {
        if (burnId < burnID++) revert StateExpired();
        (uint256 burnFee, uint256 burnAmount, uint256 daiAmount) = _burnWithFee(slxAmount);

        transfer(feeAddress, burnFee);
        _burn(msg.sender, burnAmount);
        if (!DAI.transfer(msg.sender, daiAmount)) revert DaiError();
        emit Burn(burnAmount, daiAmount, DAI.balanceOf(address(this)), block.timestamp);
    }

    function costToMint(uint256 amount) public view returns (uint256) {
        return _curveBond(totalSupply(), amount, 1);
    }

    function refundOnBurn(uint256 amount) public view returns (uint256 daiAmount) {
        (, , daiAmount) = _burnWithFee(amount);
        return daiAmount;
    }

    function _burnWithFee(
        uint256 slxAmount
    ) internal view returns (uint256 burnFee, uint256 burnAmount, uint256 daiAmount) {
        burnFee = (slxAmount * 264) / 1000;
        burnAmount = slxAmount - burnFee;
        daiAmount = _curveBond(totalSupply(), burnAmount, 0);
        return (burnFee, burnAmount, daiAmount);
    }

    function _curveBond(uint256 x, uint256 y, uint256 z) internal pure returns (uint256) {
        return
            ((z * ((2 * x * y) + y ** 2) + (1 - z) * ((2 * x * y) - y ** 2)) * 125) / (10 ** 23);
    }
}
