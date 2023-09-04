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

    constructor() ERC20("Solaxy", "SLX") ERC20Permit("Solaxy") {
        feeAddress = msg.sender;
    }

    receive() external payable {
        revert Prohibited();
    }

    function costToMint(uint256 amount) public view returns (uint256) {
        return (((totalSupply() + amount) ** 2 - totalSupply() ** 2) * 125) / 100_000;
    }

    function refundOnBurn(uint256 amount) public view returns (uint256) {
        return ((totalSupply() ** 2 - (totalSupply() - amount) ** 2) * 125) / 100_000;
    }

    function mint(uint256 slxAmount) public {
        uint256 daiAmount = costToMint(slxAmount);
        if (!DAI.transferFrom(msg.sender, address(this), daiAmount)) revert DaiError();
        emit Mint(slxAmount, daiAmount, DAI.balanceOf(address(this)), block.timestamp);
        _mint(msg.sender, slxAmount);
    }

    function burn(uint256 slxAmount) public {
        uint256 slxAmount_ = (slxAmount * 97) / 100;
        transfer(feeAddress, slxAmount - slxAmount_);

        _burn(msg.sender, slxAmount_);
        uint256 daiAmount = refundOnBurn(slxAmount_);
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
