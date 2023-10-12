// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {UD60x18, ud60x18} from "@prb/math/src/UD60x18.sol";
import "./interfaces/ISolaxy.sol";
import "./XRC20.sol";

/**
 * @title Solaxy
 * @notice Token contract implementing a linear DAI-backed bonding curve where the solpe is 25 basis points (0.0025).
 * @dev Adheres to ERC-20 token standard and uses the ERC-4626 tokenized vault interface for bonding curve operations.
 */
contract Solaxy is XRC20, ISolaxy {
    ERC20 public constant DAI =
        ERC20(0x1CbAd85Aa66Ff3C12dc84C5881886EEB29C1bb9b);
    UD60x18 public constant halfSlope = UD60x18.wrap(0.00125e18);
    address public immutable feeAddress;

    /**
     * @dev Constructs the Solaxy contract, initializing the DAI token and the fee address.
     * @param feeAccount The address where fees will be sent to.
     */
    constructor(
        address feeAccount
    ) ERC20("Solaxy", "SLX") ERC20Permit("Solaxy") {
        if (address(DAI) == address(0)) revert CannotBeZero();
        if (feeAccount == address(0)) revert CannotBeZero();
        feeAddress = feeAccount;
    }

    /** @dev Fallback function to revert Ether transfers directly to the contract. */
    receive() external payable {
        revert Prohibited();
    }

    /** @dev See {IERC4626-deposit}. */
    function deposit(
        uint256 assets,
        address receiver
    ) external returns (uint256 shares) {
        shares = _previewDeposit(assets);
        _deposit(receiver, assets, shares);
    }

    /**
     * @dev Implements {IERC4626-deposit} and protects againts slippage by specifying a minimum number of shares to receive.
     * @param minSharesOut The minimum number of shares the sender expects to receive.
     */
    function deposit(
        uint256 assets,
        address receiver,
        uint256 minSharesOut
    ) external returns (uint256 shares) {
        shares = _previewDeposit(assets);
        if (shares < minSharesOut) revert AvertSlippage();
        _deposit(receiver, assets, shares);
    }

    /** @dev See {IERC4626-withdraw}. */
    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) external returns (uint256 shares) {
        uint256 fee;
        (shares, fee) = _previewWithdraw(assets);
        _withdraw(receiver, owner, assets, shares, fee);
    }

    /**
     * @dev Implements {IERC4626-withdraw} and protects againts slippage by specifying a maximum number of shares to burn.
     * @param maxSharesIn The maximum number of shares the sender is willing to burn.
     */
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

    /** @dev See {IERC4626-mint}. */
    function mint(
        uint256 shares,
        address receiver
    ) external returns (uint256 assets) {
        assets = _previewMint(shares);
        _deposit(receiver, assets, shares);
    }

    /**
     * @dev Implements {IERC4626-deposit} and protects againts slippage by specifying a maximum amount of assets to deposit.
     * @param maxAssetsIn The maximum amount of assets the sender is willing to deposit.
     */
    function mint(
        uint256 shares,
        address receiver,
        uint256 maxAssetsIn
    ) external returns (uint256 assets) {
        assets = _previewMint(shares);
        if (assets > maxAssetsIn) revert AvertSlippage();
        _deposit(receiver, assets, shares);
    }

    /** @dev See {IERC4626-redeem}. */
    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) external returns (uint256 assets) {
        uint256 fee;
        (shares, assets, fee) = _previewRedeem(shares);
        _withdraw(receiver, owner, assets, shares, fee);
    }

    /**
     * @dev Implements {IERC4626-redeem} and protects againts slippage by specifying a minimum amount of assets to receive.
     * @param minAssetsOut The minimum amount of assets the sender expects to receive.
     */
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

    /** @dev See {IERC4626-previewDeposit}. */
    function previewDeposit(
        uint256 assets
    ) external view returns (uint256 shares) {
        return _previewDeposit(assets);
    }

    /** @dev See {IERC4626-previewWithdraw}. */
    function previewWithdraw(
        uint256 assets
    ) external view returns (uint256 shares) {
        uint256 fee;
        (shares, fee) = _previewWithdraw(assets);
        return shares + fee;
    }

    /** @dev See {IERC4626-previewMint}. */
    function previewMint(
        uint256 shares
    ) external view returns (uint256 assets) {
        return _previewMint(shares);
    }

    /** @dev See {IERC4626-previewRedeem}. */
    function previewRedeem(
        uint256 shares
    ) external view returns (uint256 assets) {
        (, assets, ) = _previewRedeem(shares);
    }

    /** @dev See {IERC4626-convertToShares}. */
    function convertToShares(
        uint256 assets
    ) external view returns (uint256 shares) {
        if (totalAssets() < assets) revert Undersupply();
        return ud60x18(assets).div(currentPrice()).intoUint256();
    }

    /** @dev See {IERC4626-convertToAssets}. */
    function convertToAssets(
        uint256 shares
    ) external view returns (uint256 assets) {
        if (totalSupply() < shares) revert Undersupply();
        return ud60x18(shares).mul(currentPrice()).intoUint256();
    }

    /** @dev See {IERC4626-maxWithdraw}. */
    function maxWithdraw(
        address owner
    ) external view returns (uint256 maxAssets) {
        (, maxAssets, ) = _previewRedeem(balanceOf(owner));
    }

    /** @dev See {IERC4626-maxRedeem}. */
    function maxRedeem(
        address owner
    ) external view returns (uint256 maxShares) {
        return balanceOf(owner);
    }

    /** @dev See {IERC4626-maxDeposit}. */
    function maxDeposit(address) external pure returns (uint256 maxAssets) {
        return type(uint256).max;
    }

    /** @dev See {IERC4626-maxMint}. */
    function maxMint(address) external pure returns (uint256 maxShares) {
        return type(uint256).max;
    }

    /** @dev See {IERC4626-asset}. */
    function asset() external pure returns (address assetTokenAddress) {
        return address(DAI);
    }

    /** @dev See {IERC4626-totalAssets}. */
    function totalAssets() public view returns (uint256 totalManagedAssets) {
        return DAI.balanceOf(address(this));
    }

    /**
     * @notice Computes the current price of the shares, using the linear slope function: f(x) = mx + c,
     * where `x` is the total supply of shares, `m`, the slope is 25 basis points and `c` is 0.
     *
     * @return price The current price along the bonding curve.
     */
    function currentPrice() public view returns (UD60x18) {
        return ud60x18(totalSupply()).mul(halfSlope).mul(ud60x18(2e18));
    }

    /** @dev Deposit/mint common workflow. */
    function _deposit(
        address receiver,
        uint256 assets,
        uint256 shares
    ) internal {
        if (assets == 0) revert CannotBeZero();
        if (shares == 0) revert CannotBeZero();
        if (!DAI.transferFrom(msg.sender, address(this), assets))
            revert TransferFailed();
        emit Deposit(msg.sender, receiver, assets, shares);
        _mint(receiver, shares);
    }

    /** @dev Withdraw/redeem common workflow. */
    function _withdraw(
        address receiver,
        address owner,
        uint256 assets,
        uint256 shares,
        uint256 fee
    ) internal {
        if (fee == 0) revert CannotBeZero();
        if (assets == 0) revert CannotBeZero();
        if (shares == 0) revert CannotBeZero();
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

    /**
     * @notice Computes the number of shares to be minted for a given amount of assets to be deposited.
     * Utilizes the equation y = sqrt((0.00125x^2 + A) / 0.00125) - x, derived from the trapezium area formula.
     *
     * @param assets The amount of assets to be deposited.
     * @return shares The calculated number of shares minted for the deposited assets.
     */
    function _previewDeposit(
        uint256 assets
    ) internal view returns (uint256 shares) {
        UD60x18 initalSupply = ud60x18(totalSupply());
        shares = initalSupply
            .powu(2)
            .add(ud60x18(assets).div(halfSlope))
            .sqrt()
            .sub(initalSupply)
            .intoUint256();
    }

    /**
     * @notice Computes the number of shares to be burned and the exit fee for a given amount of assets to be withdrawn.
     * Utilizes the equation y = x - sqrt((0.00125x^2 - A) / 0.00125), derived from the trapezium area formula.
     * Applies a 35.9% exit fee on the calculated shares.
     *
     * @dev Throws an error if the total assets are less than the specified withdrawal amount.
     * @param assets The amount of assets to be withdrawn.
     * @return shares The calculated number of shares to be burned in the withdrawal.
     * @return fee The exit fee included in the required shares.
     */
    function _previewWithdraw(
        uint256 assets
    ) internal view returns (uint256 shares, uint256 fee) {
        if (totalAssets() < assets) revert Undersupply();
        UD60x18 initialSupply = ud60x18(totalSupply());
        UD60x18 withdrawnShares = initialSupply.sub(
            initialSupply.powu(2).sub(ud60x18(assets).div(halfSlope)).sqrt()
        );

        shares = withdrawnShares.intoUint256();
        fee = withdrawnShares.mul(ud60x18(0.359e18)).intoUint256();
    }

    /**
     * @notice Computes the assets to be minted for a given number of shares using _convertToAssets.
     * @param shares The number of shares to be minted.
     * @return assets The computed assets as a uint256 value.
     */
    function _previewMint(
        uint256 shares
    ) internal view returns (uint256 assets) {
        return
            _convertToAssets(
                ud60x18(totalSupply()),
                ud60x18(totalSupply() + shares)
            ).intoUint256();
    }

    /**
     * @notice Computes the assets, burnShares, and exit fee for a given number of shares to be redeemed.
     * It calculates the assets to be redeemed using the _convertToAssets function and applies a 26.4% exit fee.
     *
     * @param shares The number of shares to be redeemed.
     * @return burnShare The number of shares to be burned.
     * @return assets The computed assets as a uint256 value.
     * @return fee The exit fee deducted from the redeemed assets as a uint256 value.
     */
    function _previewRedeem(
        uint256 shares
    ) internal view returns (uint256 burnShare, uint256 assets, uint256 fee) {
        if (totalSupply() < shares) revert Undersupply();
        UD60x18 _fee = ud60x18(shares).mul(ud60x18(0.264e18));
        UD60x18 _burnShare = ud60x18(shares).sub(_fee);

        UD60x18 initalSupply = ud60x18(totalSupply());
        UD60x18 finalSupply = initalSupply.sub(_burnShare);

        UD60x18 _assets = _convertToAssets(finalSupply, initalSupply);
        return (
            _burnShare.intoUint256(),
            _assets.intoUint256(),
            _fee.intoUint256()
        );
    }

    /**
     * @notice Computes assets as the area under a linear curve with a simplified form of the area of a trapezium,
     * f(x) = mx + c, and Area = 1/2 * (a + b) * h
     * where `a` and `b` can be both f(juniorSupply) or f(seniorSupply) depending if used in minting or redeeming.
     * Calculates area as (seniorSupply^2 - juniorSupply^2) * halfSlope, where halfSlope = (slope / 2)
     *
     * @param juniorSupply The smaller supply in the operation (the initial supply during mint,
     * or the final supply during a redeem operation).
     * @param seniorSupply The larger supply in the operation (the final supply during mint,
     * or the initial supply during a redeem operation).
     * @return assets The computed assets as an instance of UD60x18 (a fixed-point number).
     */
    function _convertToAssets(
        UD60x18 juniorSupply,
        UD60x18 seniorSupply
    ) internal pure returns (UD60x18 assets) {
        UD60x18 sqrDiff = seniorSupply.powu(2).sub(juniorSupply.powu(2));
        return sqrDiff.mul(halfSlope);
    }
}
