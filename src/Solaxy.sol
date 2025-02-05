// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ISolaxy} from "./interfaces/ISolaxy.sol";
import {UD60x18, ud60x18} from "@prb/math@4.1.0/src/UD60x18.sol";
import {SafeERC20} from "@openzeppelin/contracts@5.2.0/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts@5.2.0/utils/ReentrancyGuard.sol";
import {ERC20Permit, ERC20} from "@openzeppelin/contracts@5.2.0/token/ERC20/extensions/ERC20Permit.sol";

/**
 * @title Solaxy
 * @author ichristwin.eth
 * @notice Token contract implementing a linear asset-backed bonding curve where the slope is 0.000025.
 * @dev Adheres to ERC-20 token standard and uses the ERC-4626 tokenized vault interface for bonding curve operations.
 * @custom:security-contact 25nzij1r3@mozmail.com
 */
contract Solaxy is ISolaxy, ERC20Permit, ReentrancyGuard {
    using SafeERC20 for ERC20;

    ERC20 constant RESERVE = ERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F); // ToDo: use asset L1 contract address
    address constant M3TER = 0x9C8fF314C9Bc7F6e59A9d9225Fb22946427eDC03; // ToDo: use m3ter L1 contract address
    UD60x18 constant SEMI_SLOPE = UD60x18.wrap(0.0000125e18);

    constructor() payable ERC20("Solaxy", "SLX") ERC20Permit("Solaxy") {}

    /**
     * @notice Implements {IERC4626-deposit} and protects against slippage by specifying a minimum number of shares to receive.
     * @param minSharesOut The minimum number of shares the sender expects to receive.
     */
    function safeDeposit(uint256 assets, address receiver, uint256 minSharesOut) external returns (uint256 shares) {
        shares = deposit(assets, receiver);
        if (shares < minSharesOut) revert SlippageError();
    }

    /**
     * @notice Implements {IERC4626-withdraw} and protects against slippage by specifying a maximum number of shares to burn.
     * @param maxSharesIn The maximum number of shares the sender is willing to burn.
     */
    function safeWithdraw(uint256 assets, address receiver, address owner, uint256 maxSharesIn)
        external
        returns (uint256 shares)
    {
        shares = withdraw(assets, receiver, owner);
        if (shares > maxSharesIn) revert SlippageError();
    }

    /**
     * @notice Implements {IERC4626-deposit} and protects against slippage by specifying a maximum amount of assets to deposit.
     * @param maxAssetsIn The maximum amount of assets the sender is willing to deposit.
     */
    function safeMint(uint256 shares, address receiver, uint256 maxAssetsIn) external returns (uint256 assets) {
        assets = mint(shares, receiver);
        if (assets > maxAssetsIn) revert SlippageError();
    }

    /**
     * @notice Implements {IERC4626-redeem} and protects against slippage by specifying a minimum amount of assets to receive.
     * @param minAssetsOut The minimum amount of assets the sender expects to receive.
     */
    function safeRedeem(uint256 shares, address receiver, address owner, uint256 minAssetsOut)
        external
        returns (uint256 assets)
    {
        assets = redeem(shares, receiver, owner);
        if (assets < minAssetsOut) revert SlippageError();
    }

    function convertToShares(uint256 assets) external view returns (uint256 shares) {
        shares = ud60x18(assets).div(ud60x18(2 * totalSupply()).mul(SEMI_SLOPE)).intoUint256();
    }

    function convertToAssets(uint256 shares) external view returns (uint256 assets) {
        assets = ud60x18(shares).mul(ud60x18(2 * totalSupply()).mul(SEMI_SLOPE)).intoUint256();
    }

    function maxWithdraw(address owner) external view returns (uint256 maxAssets) {
        maxAssets = previewRedeem(balanceOf(owner));
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

    function deposit(uint256 assets, address receiver) public returns (uint256 shares) {
        shares = previewDeposit(assets);
        _pump(receiver, assets, shares);
    }

    function withdraw(uint256 assets, address receiver, address owner) public returns (uint256 shares) {
        shares = previewWithdraw(assets);
        _dump(receiver, owner, assets, shares);
    }

    function mint(uint256 shares, address receiver) public returns (uint256 assets) {
        assets = previewMint(shares);
        _pump(receiver, assets, shares);
    }

    function redeem(uint256 shares, address receiver, address owner) public returns (uint256 assets) {
        assets = previewRedeem(shares);
        _dump(receiver, owner, assets, shares);
    }

    function totalAssets() public view returns (uint256 totalManagedAssets) {
        totalManagedAssets = RESERVE.balanceOf(address(this));
    }

    /**
     * @notice Computes the number of shares to be minted for a given amount of assets to be deposited.
     * @dev Utilizes the equation y = sqrt((0.0000125x^2 + A) / 0.0000125) - x, derived from the trapezium area formula.
     * @param assets The amount of assets to be deposited.
     * @return shares The calculated number of shares minted for the deposited assets.
     */
    function previewDeposit(uint256 assets) public view override returns (uint256 shares) {
        UD60x18 totalShares = ud60x18(totalSupply());
        shares = totalShares.powu(2).add(ud60x18(assets).div(SEMI_SLOPE)).sqrt().sub(totalShares).intoUint256();
    }

    /**
     * @notice Computes the number of shares to be burned for a given amount of assets to be withdrawn.
     * @dev Utilizes the equation y = x - sqrt((0.0000125x^2 - A) / 0.0000125), derived from the trapezium area formula.
     * @param assets The amount of assets to be withdrawn.
     * @return shares The calculated number of shares to be burned in the withdrawal.
     */
    function previewWithdraw(uint256 assets) public view returns (uint256 shares) {
        UD60x18 totalShares = ud60x18(totalSupply());
        shares = totalShares.sub(totalShares.powu(2).sub(ud60x18(assets).div(SEMI_SLOPE)).sqrt()).intoUint256();
    }

    /**
     * @notice Computes the amount of assets to be deposited for a given number of shares minted.
     * @dev Computes assets as the area under a linear curve with a simplified form of the area of a trapezium,
     * f(x) = mx + c, and Area = 1/2 * (a + b) * h
     * Calculates area as SemiSlope * (amountY^2 - amountX^2), where SemiSlope = (0.000025 / 2)
     * where amountX is the initial supply during mint and amountY is the final supply during mint
     * @param shares The number of shares to be minted.
     * @return assets The computed assets as a uint256 value.
     */
    function previewMint(uint256 shares) public view returns (uint256 assets) {
        UD60x18 totalShares = ud60x18(totalSupply());
        assets = SEMI_SLOPE.mul((totalShares + ud60x18(shares)).powu(2).sub(totalShares.powu(2))).intoUint256();
    }

    /**
     * @notice Computes the amount of assets to be withdrawn for a given number of shares burned.
     * @dev Computes assets as the area under a linear curve with a simplified form of the area of a trapezium,
     * f(x) = mx + c, and Area = 1/2 * (a + b) * h
     * Calculates area as SemiSlope * (amountY^2 - amountX^2), where SemiSlope = (0.000025 / 2)
     * where amountX is the final supply during redeem and amountY is the initial supply during redeem
     * @param shares The number of shares to be redeemed.
     * @return assets The computed assets as a uint256 value.
     */
    function previewRedeem(uint256 shares) public view returns (uint256 assets) {
        UD60x18 totalShares = ud60x18(totalSupply());
        assets = SEMI_SLOPE.mul(totalShares.powu(2).sub(totalShares.sub(ud60x18(shares)).powu(2))).intoUint256();
    }

    /**
     * @dev Deposit/mint common workflow. Updates vault balances and handles external to reserve asset contract
     * Reverts if vault balances are not consistent with expectations, only handles consistency checks for vault account
     */
    function _pump(address receiver, uint256 assets, uint256 shares) private nonReentrant {
        (bool success, bytes memory data) = M3TER.staticcall(abi.encodeWithSignature("balanceOf(address)", receiver));
        if (!success) revert StaticCallFailed();
        if (abi.decode(data, (uint256)) < 1) revert RequiresM3ter();

        (uint256 initialAssets, uint256 initialShares) = (totalAssets(), totalSupply());
        RESERVE.safeTransferFrom(msg.sender, address(this), assets);
        _mint(receiver, shares);

        if (totalAssets() != initialAssets + assets) revert InconsistentBalances();
        if (totalSupply() != initialShares + shares) revert InconsistentBalances();
        emit Deposit(msg.sender, receiver, assets, shares);
    }

    /**
     * @dev Withdraw/redeem common workflow. Updates vault balances and handles external to reserve asset contract
     * Collects a 7% tip on the underlying asset based on the price of shares after redemption/withdrawal
     * Reverts if vault balances are not consistent with expectations, only handles consistency checks for vault account
     */
    function _dump(address receiver, address owner, uint256 assets, uint256 shares) private nonReentrant {
        address accImpProxy = 0x55266d75D1a14E4572138116aF39863Ed6596E7F; // @ ERC6551 v0.3.1 account implementation proxy
        (bool success, bytes memory rawTipAccount) = 0x000000006551c19487814612e58FE06813775758.staticcall( // @ ERC6551 v0.3.1 registry
        abi.encodeWithSignature("account(address,bytes32,uint256,address,uint256)", accImpProxy, 0x0, 1, M3TER, 0));
        if (!success) revert StaticCallFailed();

        (uint256 initialAssets, uint256 initialShares) = (totalAssets(), totalSupply());
        uint256 tip = ud60x18(7).div(ud60x18(186)).mul(ud60x18(assets)).div(
            SEMI_SLOPE.mul(ud60x18(initialShares).sub(ud60x18(shares)))
        ).intoUint256();

        RESERVE.safeTransfer(receiver, assets);
        if (msg.sender != owner) _spendAllowance(owner, msg.sender, shares + tip);
        _transfer(owner, abi.decode(rawTipAccount, (address)), tip);
        _burn(owner, shares);

        if (totalAssets() != initialAssets - assets) revert InconsistentBalances();
        if (totalSupply() != initialShares - shares) revert InconsistentBalances();
        emit Withdraw(msg.sender, receiver, owner, assets, shares);
    }
}
