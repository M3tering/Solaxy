// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {UD60x18, ud60x18} from "@prb/math/src/UD60x18.sol";

import "./XRC20.sol";

error Prohibited();
error Undersupply();
error ZeroAddress();
error AvertSlippage();
error TransferFailed();

contract Solaxy is XRC20, IERC4626 {
    ERC20 public constant DAI =
        ERC20(0x1CbAd85Aa66Ff3C12dc84C5881886EEB29C1bb9b);
    UD60x18 public constant oneEighthBPS = UD60x18.wrap(0.00125e18);
    address public immutable feeAddress;

    constructor() ERC20("Solaxy", "SLX") ERC20Permit("Solaxy") {
        if (address(DAI) == address(0)) revert ZeroAddress();
        feeAddress = msg.sender;
    }

    receive() external payable {
        revert Prohibited();
    }

    function deposit(
        uint256 assets,
        address receiver
    ) external returns (uint256 shares) {
        shares = _previewDeposit(assets);
        _deposit(receiver, assets, shares);
    }

    function deposit(
        uint256 assets,
        address receiver,
        uint256 minSharesOut
    ) external returns (uint256 shares) {
        shares = _previewDeposit(assets);
        if (shares < minSharesOut) revert AvertSlippage();
        _deposit(receiver, assets, shares);
    }

    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) external returns (uint256 shares) {
        uint256 fee;
        (shares, fee) = _previewWithdraw(assets);
        _withdraw(receiver, owner, assets, shares, fee);
    }

    function withdraw(
        uint256 assets,
        address receiver,
        address owner,
        uint256 maxSharesIn
    ) external returns (uint256 shares) {
        uint256 fee;
        (shares, fee) = _previewWithdraw(assets);
        if (shares > maxSharesIn) revert AvertSlippage();
        _withdraw(receiver, owner, assets, shares, fee);
    }

    function mint(
        uint256 shares,
        address receiver
    ) external returns (uint256 assets) {
        assets = _previewMint(shares);
        _deposit(receiver, assets, shares);
    }

    function mint(
        uint256 shares,
        address receiver,
        uint256 maxAssetsIn
    ) external returns (uint256 assets) {
        assets = _previewMint(shares);
        if (assets > maxAssetsIn) revert AvertSlippage();
        _deposit(receiver, assets, shares);
    }

    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) external returns (uint256 assets) {
        uint256 fee;
        (shares, assets, fee) = _previewRedeem(shares);
        _withdraw(receiver, owner, assets, shares, fee);
    }

    function redeem(
        uint256 shares,
        address receiver,
        address owner,
        uint256 minAssetsOut
    ) external returns (uint256 assets) {
        uint256 fee;
        (shares, assets, fee) = _previewRedeem(shares);
        if (assets < minAssetsOut) revert AvertSlippage();
        _withdraw(receiver, owner, assets, shares, fee);
    }

    function previewDeposit(
        uint256 assets
    ) external view returns (uint256 shares) {
        return _previewDeposit(assets);
    }

    function previewWithdraw(
        uint256 assets
    ) external view returns (uint256 shares) {
        (shares, ) = _previewWithdraw(assets);
    }

    function previewMint(
        uint256 shares
    ) external view returns (uint256 assets) {
        return _previewMint(shares);
    }

    function previewRedeem(
        uint256 shares
    ) external view returns (uint256 assets) {
        (, assets, ) = _previewRedeem(shares);
    }

    function convertToShares(
        uint256 assets
    ) external view returns (uint256 shares) {
        return ud60x18(assets).div(currentPrice()).intoUint256();
    }

    function convertToAssets(
        uint256 shares
    ) external view returns (uint256 assets) {
        return ud60x18(shares).mul(currentPrice()).intoUint256();
    }

    function maxWithdraw(
        address owner
    ) external view returns (uint256 maxAssets) {
        (, maxAssets, ) = _previewRedeem(balanceOf(owner));
    }

    function maxRedeem(
        address owner
    ) external view returns (uint256 maxShares) {
        return balanceOf(owner);
    }

    function maxDeposit(
        address receiver
    ) external pure returns (uint256 maxAssets) {
        return type(uint256).max;
    }

    function maxMint(
        address receiver
    ) external pure returns (uint256 maxShares) {
        return type(uint256).max;
    }

    function asset() external pure returns (address assetTokenAddress) {
        return address(DAI);
    }

    function totalAssets() public view returns (uint256 totalManagedAssets) {
        return DAI.balanceOf(address(this));
    }

    function currentPrice() public view returns (UD60x18) {
        return ud60x18(totalSupply()).mul(oneEighthBPS).mul(ud60x18(2e18));
    }

    function _deposit(
        address receiver,
        uint256 assets,
        uint256 shares
    ) internal {
        if (!DAI.transferFrom(msg.sender, address(this), assets))
            revert TransferFailed();
        emit Deposit(msg.sender, receiver, assets, shares);
        _mint(receiver, shares);
    }

    function _withdraw(
        address receiver,
        address owner,
        uint256 assets,
        uint256 shares,
        uint256 fee
    ) internal {
        if (totalAssets() < assets) revert Undersupply();
        if (totalSupply() < shares) revert Undersupply();
        if (msg.sender != owner) {
            _spendAllowance(owner, msg.sender, shares + fee);
        }
        _burn(owner, shares);

        if (!transfer(feeAddress, fee)) revert TransferFailed();
        if (!DAI.transfer(receiver, assets)) revert TransferFailed();
        emit Withdraw(msg.sender, receiver, owner, assets, shares);
    }

    function _previewDeposit(uint256 assets) internal view returns (uint256) {
        UD60x18 initalSupply = ud60x18(totalSupply());
        UD60x18 finalSupply = initalSupply
            .powu(2)
            .add(ud60x18(assets).div(oneEighthBPS))
            .sqrt();
        return finalSupply.sub(initalSupply).intoUint256();
    }

    function _previewWithdraw(
        uint256 assets
    ) internal view returns (uint256, uint256) {
        UD60x18 initalSupply = ud60x18(totalSupply());
        UD60x18 finalSupply = initalSupply
            .powu(2)
            .sub(ud60x18(assets).div(oneEighthBPS))
            .sqrt();
        UD60x18 shares = initalSupply.sub(finalSupply);
        return (
            shares.intoUint256(),
            ud60x18(0.359e18).mul(shares).intoUint256()
        );
    }

    function _previewMint(
        uint256 shares
    ) internal view returns (uint256 assets) {
        UD60x18 initalSupply = ud60x18(totalSupply());
        UD60x18 finalSupply = initalSupply.add(ud60x18(shares));

        return _convertToAssets(initalSupply, finalSupply).intoUint256();
    }

    function _previewRedeem(
        uint256 shares
    ) internal view returns (uint256, uint256, uint256) {
        UD60x18 initalSupply = ud60x18(totalSupply());
        UD60x18 shares = ud60x18(shares);

        UD60x18 fee = ud60x18(0.264e18).mul(shares);
        UD60x18 burnShare = shares.sub(fee);
        UD60x18 finalSupply = initalSupply.sub(burnShare);

        UD60x18 assets = _convertToAssets(initalSupply, finalSupply);
        return (
            burnShare.intoUint256(),
            assets.intoUint256(),
            fee.intoUint256()
        );
    }

    function _convertToAssets(
        UD60x18 juniorSupply,
        UD60x18 seniorSupply
    ) internal pure returns (UD60x18 assets) {
        UD60x18 sqrDiff = seniorSupply.powu(2).sub(juniorSupply.powu(2));
        return sqrDiff.mul(oneEighthBPS);
    }
}
