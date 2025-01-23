// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ISolaxy} from "./interfaces/ISolaxy.sol";
import {IERC6551Account} from "./interfaces/IERC6551Account.sol";
import {IERC6551Registry} from "./interfaces/IERC6551Registry.sol";
import {UD60x18, ud60x18} from "@prb/math@4.1.0/src/UD60x18.sol";
import {ERC20} from "@openzeppelin/contracts@5.2.0/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts@5.2.0/token/ERC20/extensions/ERC20Permit.sol";
import {ERC20FlashMint} from "@openzeppelin/contracts@5.2.0/token/ERC20/extensions/ERC20FlashMint.sol";

/**
 * @title Solaxy
 * @author ichristwin.eth
 * @notice Token contract implementing a linear asset-backed bonding curve where the slope is 0.000025.
 * @dev Adheres to ERC-20 token standard and uses the ERC-4626 tokenized vault interface for bonding curve operations.
 * @custom:security-contact 25nzij1r3@mozmail.com
 */
contract Solaxy is ISolaxy, ERC20Permit, ERC20FlashMint {
    UD60x18 public constant SEMI_SLOPE = UD60x18.wrap(0.0000125e18);
    address public constant M3TER = 0x0000000000000000000000000000000000000000; // ToDo: use m3ter L1 contract address
    ERC20 public constant RESERVE = ERC20(0x0000000000000000000000000000000000000000); // ToDo: use asset L1 contract address

    modifier onlyM3terAccount(address account) {
        (uint256 chainId, address tokenContract, uint256 tokenId) = IERC6551Account(account).token();
        if (tokenContract != M3TER || chainId != block.chainid) revert RequiresM3ter();
        _;
    }

    constructor() ERC20("Solaxy", "SLX") ERC20Permit("Solaxy") {}

    function deposit(uint256 assets, address receiver) external onlyM3terAccount(receiver) returns (uint256 shares) {
        shares = computeDeposit(assets, totalSupply());
        _deposit(receiver, assets, shares);
    }

    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256 shares) {
        uint256 tip;
        (shares, tip) = computeWithdraw(assets, totalSupply());
        _withdraw(receiver, owner, assets, shares, tip);
    }

    function mint(uint256 shares, address receiver) external onlyM3terAccount(receiver) returns (uint256 assets) {
        assets = computeMint(shares, totalSupply());
        _deposit(receiver, assets, shares);
    }

    function redeem(uint256 shares, address receiver, address owner) external returns (uint256 assets) {
        uint256 tip;
        (shares, assets, tip) = computeRedeem(shares, totalSupply());
        _withdraw(receiver, owner, assets, shares, tip);
    }

    /**
     * @dev Implements {IERC4626-deposit} and protects against slippage by specifying a minimum number of shares to receive.
     * @param minSharesOut The minimum number of shares the sender expects to receive.
     */
    function safeDeposit(uint256 assets, address receiver, uint256 minSharesOut)
        external
        onlyM3terAccount(receiver)
        returns (uint256 shares)
    {
        shares = computeDeposit(assets, totalSupply());
        if (shares < minSharesOut) revert SlippageError();
        _deposit(receiver, assets, shares);
    }

    /**
     * @dev Implements {IERC4626-withdraw} and protects against slippage by specifying a maximum number of shares to burn.
     * @param maxSharesIn The maximum number of shares the sender is willing to burn.
     */
    function safeWithdraw(uint256 assets, address receiver, address owner, uint256 maxSharesIn)
        external
        returns (uint256 shares)
    {
        uint256 tip;
        (shares, tip) = computeWithdraw(assets, totalSupply());
        if (shares > maxSharesIn) revert SlippageError();
        _withdraw(receiver, owner, assets, shares, tip);
    }

    /**
     * @dev Implements {IERC4626-deposit} and protects against slippage by specifying a maximum amount of assets to deposit.
     * @param maxAssetsIn The maximum amount of assets the sender is willing to deposit.
     */
    function safeMint(uint256 shares, address receiver, uint256 maxAssetsIn)
        external
        onlyM3terAccount(receiver)
        returns (uint256 assets)
    {
        assets = computeMint(shares, totalSupply());
        if (assets > maxAssetsIn) revert SlippageError();
        _deposit(receiver, assets, shares);
    }

    /**
     * @dev Implements {IERC4626-redeem} and protects against slippage by specifying a minimum amount of assets to receive.
     * @param minAssetsOut The minimum amount of assets the sender expects to receive.
     */
    function safeRedeem(uint256 shares, address receiver, address owner, uint256 minAssetsOut)
        external
        returns (uint256 assets)
    {
        uint256 tip;
        (shares, assets, tip) = computeRedeem(shares, totalSupply());
        if (assets < minAssetsOut) revert SlippageError();
        _withdraw(receiver, owner, assets, shares, tip);
    }

    function previewDeposit(uint256 assets) external view returns (uint256 shares) {
        return computeDeposit(assets, totalSupply());
    }

    function previewWithdraw(uint256 assets) external view returns (uint256 shares) {
        uint256 tip;
        if (totalAssets() < assets) revert Undersupply();
        (shares, tip) = computeWithdraw(assets, totalSupply());
        return shares + tip;
    }

    function previewMint(uint256 shares) external view returns (uint256 assets) {
        return computeMint(shares, totalSupply());
    }

    function previewRedeem(uint256 shares) external view returns (uint256 assets) {
        if (totalSupply() < shares) revert Undersupply();
        (, assets,) = computeRedeem(shares, totalSupply());
    }

    /**
     * @notice Computes the current price of a share, as price = totalSupply * slope + 0
     * which is derived from the linear slope function: f(x) = mx + c,
     * where `x` is the supply of shares, the slope `m` is 0.0025, and `c` is a constant term = 0.
     *
     * @return price The current price along the bonding curve.
     */
    function currentPrice() external view returns (uint256) {
        return ud60x18(2 * totalSupply()).mul(SEMI_SLOPE).intoUint256();
    }

    function convertToShares(uint256 assets) external view returns (uint256 shares) {
        if (totalAssets() < assets) revert Undersupply();
        UD60x18 conversionPrice = ud60x18(totalSupply()).mul(SEMI_SLOPE);
        shares = ud60x18(assets).div(conversionPrice).intoUint256();
    }

    function convertToAssets(uint256 shares) external view returns (uint256 assets) {
        if (totalSupply() < shares) revert Undersupply();
        UD60x18 conversionPrice = ud60x18(totalSupply()).mul(SEMI_SLOPE);
        assets = ud60x18(shares).mul(conversionPrice).intoUint256();
    }

    function maxWithdraw(address owner) external view returns (uint256 maxAssets) {
        (, maxAssets,) = computeRedeem(balanceOf(owner), totalSupply());
    }

    function maxRedeem(address owner) external view returns (uint256 maxShares) {
        return balanceOf(owner);
    }

    function maxDeposit(address) external pure returns (uint256 maxAssets) {
        return type(uint256).max;
    }

    function maxMint(address) external pure returns (uint256 maxShares) {
        return type(uint256).max;
    }

    function asset() external pure returns (address assetTokenAddress) {
        return address(RESERVE);
    }

    function totalAssets() public view returns (uint256 totalManagedAssets) {
        totalManagedAssets = RESERVE.balanceOf(address(this));
    }

    /**
     * @notice Computes the number of shares to be minted for a given amount of assets to be deposited.
     * Utilizes the equation y = sqrt((0.00125x^2 + A) / 0.00125) - x, derived from the trapezium area formula.
     *
     * @param assets The amount of assets to be deposited.
     * @param totalShares The total supply of shares in the system.
     * @return shares The calculated number of shares minted for the deposited assets.
     */
    function computeDeposit(uint256 assets, uint256 totalShares) public pure returns (uint256 shares) {
        UD60x18 initialSupply = ud60x18(totalShares);
        shares = initialSupply.powu(2).add(ud60x18(assets).div(SEMI_SLOPE)).sqrt().sub(initialSupply).intoUint256();
    }

    /**
     * @notice Computes the number of shares to be burned and the tip for a given amount of assets to be withdrawn.
     * Utilizes the equation y = x - sqrt((0.00125x^2 - A) / 0.00125), derived from the trapezium area formula.
     * Applies a 35.9% tip on the calculated shares.
     *
     * @dev Throws an error if the total assets are less than the specified withdrawal amount.
     * @param assets The amount of assets to be withdrawn.
     * @param totalShares The total supply of shares in the system.
     * @return shares The calculated number of shares to be burned in the withdrawal.
     * @return tip The tip included in the required shares.
     */
    function computeWithdraw(uint256 assets, uint256 totalShares) public pure returns (uint256 shares, uint256 tip) {
        UD60x18 initialSupply = ud60x18(totalShares);
        UD60x18 withdrawnShares = initialSupply.sub(initialSupply.powu(2).sub(ud60x18(assets).div(SEMI_SLOPE)).sqrt());

        shares = withdrawnShares.intoUint256();
        tip = withdrawnShares.mul(ud60x18(0.359e18)).intoUint256();
    }

    /**
     * @notice Computes the assets to be minted for a given number of shares using _convertToAssets.
     * @param shares The number of shares to be minted.
     * @param totalShares The total supply of shares in the system.
     * @return assets The computed assets as a uint256 value.
     */
    function computeMint(uint256 shares, uint256 totalShares) public pure returns (uint256 assets) {
        assets = _convertToAssets(ud60x18(totalShares), ud60x18(totalShares + shares)).intoUint256();
    }

    /**
     * @notice Computes the assets, burnShares, and tip for a given number of shares to be redeemed.
     * It calculates the assets to be redeemed using the _convertToAssets function and applies a 26.4% tip.
     *
     * @param shares The number of shares to be redeemed.
     * @param totalShares The total supply of shares in the system.
     * @return burnShare The number of shares to be burned.
     * @return assets The computed assets as a uint256 value.
     * @return tip deducted from the redeemed assets as a uint256 value.
     */
    function computeRedeem(uint256 shares, uint256 totalShares)
        public
        pure
        returns (uint256 burnShare, uint256 assets, uint256 tip)
    {
        UD60x18 _tip = ud60x18(shares).mul(ud60x18(0.264e18));
        UD60x18 _burnShare = ud60x18(shares).sub(_tip);
        UD60x18 finalSupply = ud60x18(totalShares).sub(_burnShare);

        assets = _convertToAssets(finalSupply, ud60x18(totalShares)).intoUint256();
        burnShare = _burnShare.intoUint256();
        tip = _tip.intoUint256();
    }

    /**
     * @dev Returns ERC6551 account for M3ter 0.
     */
    function tipAccount() public view returns (address) {
        // ERC6551@v0.3.1 Registry contract & Implementation Proxy addresses respectively
        return IERC6551Registry(0x000000006551c19487814612e58FE06813775758).account(
            0x55266d75D1a14E4572138116aF39863Ed6596E7F, 0x0, 1, M3TER, 0
        );
    }

    /**
     * @dev Deposit/mint common workflow.
     */
    function _deposit(address receiver, uint256 assets, uint256 shares) private {
        emit Deposit(msg.sender, receiver, assets, shares);
        if (assets == shares || shares == 0) revert CannotBeZero();
        if (!RESERVE.transferFrom(msg.sender, address(this), assets)) revert TransferError();
        _mint(receiver, shares);
    }

    /**
     * @dev Withdraw/redeem common workflow.
     */
    function _withdraw(address receiver, address owner, uint256 assets, uint256 shares, uint256 tip) private {
        emit Withdraw(msg.sender, receiver, owner, assets, shares);
        if (tip == 0 || assets == 0 || shares == 0) revert CannotBeZero();
        if (totalAssets() < assets || totalSupply() < shares) revert Undersupply();
        if (msg.sender != owner) _spendAllowance(owner, msg.sender, shares + tip);
        _burn(owner, shares);
        _transfer(owner, tipAccount(), tip);
        if (!RESERVE.transfer(receiver, assets)) revert TransferError();
    }

    /**
     * @notice Computes assets as the area under a linear curve with a simplified form of the area of a trapezium,
     * f(x) = mx + c, and Area = 1/2 * (a + b) * h
     * where `a` and `b` can be both f(amountX) or f(amountY) depending if used in minting or redeeming.
     * Calculates area as SemiSlope * (amountY^2 - amountX^2), where SemiSlope = (0.000025 / 2)
     *
     * @param amountX The smaller supply in the operation (the initial supply during mint,
     * or the final supply during a redeem operation).
     * @param amountY The larger supply in the operation (the final supply during mint,
     * or the initial supply during a redeem operation).
     * @return assets The computed assets as an instance of UD60x18 (a fixed-point number).
     */
    function _convertToAssets(UD60x18 amountX, UD60x18 amountY) private pure returns (UD60x18) {
        return SEMI_SLOPE.mul(amountY.powu(2).sub(amountX.powu(2)));
    }
}
