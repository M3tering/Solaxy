// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20FlashMint.sol";

import "./ISolaxy.sol";

contract Solaxy is ISolaxy, ERC20, ERC20Permit, ERC20Votes, ERC20FlashMint {
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

    function costToMint(uint256 amount) public view returns (uint256) {
        uint256 a = totalSupply() ** 2;
        uint256 b = (totalSupply() + amount) ** 2;
        return ((b - a) * 125) / 10 ** 23;
    }

    function refundOnBurn(uint256 amount) public view returns (uint256) {
        uint256 a = (totalSupply() - amount) ** 2;
        uint256 b = totalSupply() ** 2;
        return ((b - a) * 125) / 10 ** 23;
    }

    function mint(uint256 slxAmount, uint256 mintId) public {
        if (mintId < mintID++) revert TxFrontrun();
        uint256 daiAmount = costToMint(slxAmount);
        if (!DAI.transferFrom(msg.sender, address(this), daiAmount)) revert DaiError();
        emit Mint(slxAmount, daiAmount, DAI.balanceOf(address(this)), block.timestamp);
        _mint(msg.sender, slxAmount);
    }

    function burn(uint256 slxAmount, uint256 burnId) public {
        if (burnId < burnID++) revert TxFrontrun();
        uint256 slxAmount_ = (slxAmount * 736) / 1000;
        uint256 daiAmount = refundOnBurn(slxAmount_);
        uint256 burnFee = slxAmount - slxAmount_;

        _burn(msg.sender, slxAmount_);
        transfer(feeAddress, burnFee);
        if (!DAI.transfer(msg.sender, daiAmount)) revert DaiError();
        emit Burn(slxAmount_, daiAmount, DAI.balanceOf(address(this)), block.timestamp);
    }

    // The following functions are overrides required by Solidity.

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20, ERC20Votes) {
        super._afterTokenTransfer(from, to, amount);
    }

    function _mint(address to, uint256 amount) internal override(ERC20, ERC20Votes) {
        super._mint(to, amount);
    }

    function _burn(address account, uint256 amount) internal override(ERC20, ERC20Votes) {
        super._burn(account, amount);
    }
}
