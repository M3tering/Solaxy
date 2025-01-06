// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.24;

import {ISolaxy} from "./interfaces/ISolaxy.sol";
import {IERC7802, IERC165} from "./interfaces/IERC7802.sol";
import {IOptimismMintableERC20} from "./interfaces/IOptimismMintableERC20.sol";

import {ERC20} from "@openzeppelin/contracts@5.1.0/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts@5.1.0/token/ERC20/extensions/ERC20Permit.sol";
import {ERC20FlashMint} from "@openzeppelin/contracts@5.1.0/token/ERC20/extensions/ERC20FlashMint.sol";

import {UD60x18, ud60x18} from "@prb/math@4.1.0/src/UD60x18.sol";

/**
 * @title Super Solaxy
 * @notice Token contract implementing a linear sDAI-backed bonding curve where the slope is 0.000025.
 * @dev Adheres to ERC-20 token standard and uses the ERC-4626 tokenized vault interface for bonding curve operations.
 */
contract SuperSolaxy is ISolaxy, IOptimismMintableERC20, IERC7802, ERC20, ERC20Permit, ERC20FlashMint {
    ERC20 public constant REFI_USD = ERC20(0x0d86883FAf4FfD7aEb116390af37746F45b6f378); // ToDo: use refiUSD L1 contract address
    address public constant SUPERCHAIN_TOKEN_BRIDGE = 0x4200000000000000000000000000000000000028;
    address public constant L1_STANDARD_BRIDGE_PROXY = 0x99C9fc46f92E8a1c0deC1b1747d010903E884bE1;
    address public constant L2_STANDARD_BRIDGE = 0x4200000000000000000000000000000000000010;
    UD60x18 public constant HALF_SLOPE = UD60x18.wrap(0.0000125e18);
    UD60x18 public constant SLOPE = UD60x18.wrap(0.000025e18);

    constructor() ERC20("Solaxy", "SLX") ERC20Permit("Solaxy") {
        if (address(REFI_USD) == address(0)) revert CannotBeZero();
    }

    /**
     * @notice Allows the StandardBridge on this network to mint tokens.
     * @param to Address to mint tokens to.
     * @param txAssets Amount of tokens to deposited to superchain bridge.
     */
    function mint(address to, uint256 txAssets) external {
        if (msg.sender != L2_STANDARD_BRIDGE) revert Unauthorized();
        if (txAssets == 0) revert CannotBeZero();

        uint256 shares = _computeShares(ud60x18(totalAssets()), ud60x18(txAssets)).intoUint256();
        if (shares == 0) revert CannotBeZero();

        emit Deposit(msg.sender, to, txAssets, shares);
        _mint(to, shares);
    }

    /**
     * @notice Allows the StandardBridge on this network to burn tokens.
     * @param from Address to mint tokens to.
     * @param txAssets Amount of tokens to be withdrawn to superchain bridge.
     */
    function burn(address from, uint256 txAssets) external {
        if (msg.sender != L2_STANDARD_BRIDGE) revert Unauthorized();
        if (txAssets == 0) revert CannotBeZero();

        uint256 assetTotal = totalAssets();
        if (txAssets > assetTotal) revert Undersupply();

        uint256 shares = _computeShares(ud60x18(assetTotal), ud60x18(txAssets)).intoUint256();
        if (shares > totalSupply()) revert Undersupply();
        if (shares == 0) revert CannotBeZero();

        emit Withdraw(msg.sender, from, from, txAssets, shares);
        _spendAllowance(from, msg.sender, shares);
        _burn(from, shares);
    }

    /**
     * @notice Allows the SuperchainTokenBridge to mint tokens.
     * @param to Address to mint tokens to.
     * @param tokenAmount Amount of tokens to mint.
     */
    function crosschainMint(address to, uint256 tokenAmount) external {
        if (msg.sender != SUPERCHAIN_TOKEN_BRIDGE) revert Unauthorized();
        emit CrosschainMint(to, tokenAmount, msg.sender);
        _mint(to, tokenAmount);
    }

    /**
     * @notice Allows the SuperchainTokenBridge to burn tokens.
     * @param from Address to burn tokens from.
     * @param tokenAmount Amount of tokens to burn.
     */
    function crosschainBurn(address from, uint256 tokenAmount) external {
        if (msg.sender != SUPERCHAIN_TOKEN_BRIDGE) revert Unauthorized();
        emit CrosschainBurn(from, tokenAmount, msg.sender);
        _spendAllowance(from, msg.sender, tokenAmount);
        _burn(from, tokenAmount);
    }

    function supportsInterface(bytes4 _interfaceId) external view virtual returns (bool) {
        return _interfaceId == type(ERC20).interfaceId || _interfaceId == type(IOptimismMintableERC20).interfaceId
            || _interfaceId == type(IERC7802).interfaceId || _interfaceId == type(IERC165).interfaceId;
    }

    /**
     * @dev See {IERC4626-convertToShares}.
     */
    function convertToShares(uint256 assets) external view returns (uint256 shares) {
        shares = ud60x18(assets).div(ud60x18(currentPrice())).intoUint256();
    }

    /**
     * @dev See {IERC4626-convertToAssets}.
     */
    function convertToAssets(uint256 shares) external view returns (uint256 assets) {
        assets = ud60x18(shares).mul(ud60x18(currentPrice())).intoUint256();
    }

    /**
     * @dev See {IERC4626-previewDeposit}.
     */
    function previewDeposit(uint256 assets) external view returns (uint256 shares) {
        return _computeShares(ud60x18(totalAssets() + assets), ud60x18(assets)).intoUint256();
    }

    /**
     * @dev See {IERC4626-previewMint}.
     */
    function previewMint(uint256 shares) external view returns (uint256 assets) {
        return ud60x18(totalShares() + shares).powu(2).mul(HALF_SLOPE).sub(ud60x18(totalAssets())).intoUint256();
    }

    /**
     * @dev See {IERC4626-maxWithdraw}.
     */
    function maxWithdraw(address owner) external view returns (uint256 maxAssets) {
        maxAssets = previewRedeem(balanceOf(owner));
    }

    /**
     * @dev See {IERC4626-previewWithdraw}.
     */
    function previewWithdraw(uint256 assets) external view returns (uint256 shares) {
        return _computeShares(ud60x18(totalAssets()), ud60x18(assets)).intoUint256();
    }

    /**
     * @dev See {IERC4626-maxRedeem}.
     */
    function maxRedeem(address owner) external view returns (uint256 maxShares) {
        return balanceOf(owner);
    }

    /**
     * @dev See {IERC4626-maxDeposit}.
     */
    function maxDeposit(address) external pure returns (uint256 maxAssets) {
        return type(uint256).max;
    }

    /**
     * @dev See {IERC4626-maxMint}.
     */
    function maxMint(address) external pure returns (uint256 maxShares) {
        return type(uint256).max;
    }

    /**
     * @dev See {IERC4626-asset}.
     */
    function asset() external pure returns (address assetTokenAddress) {
        return address(REFI_USD);
    }

    function remoteToken() external pure returns (address) {
        return address(REFI_USD);
    }

    function bridge() external pure returns (address) {
        return L2_STANDARD_BRIDGE;
    }

    /**
     * @dev See {IERC4626-previewRedeem}.
     */
    function previewRedeem(uint256 shares) public view returns (uint256 assets) {
        return ud60x18(totalAssets()).sub(ud60x18(totalShares() - shares).powu(2).mul(HALF_SLOPE)).intoUint256();
    }

    /**
     * @dev See {IERC4626-totalAssets}.
     */
    function totalAssets() public view returns (uint256) {
        // ToDo: Implement L1SLOAD or L1CALL or REMOTESTATICCALL
        // to read the total amount of REMOTE_TOKEN deposited on
        // the superchain bridge contract on the L1

        /*
        (bool success, bytes memory result) = L1SLOAD_PRECOMPILE.staticcall(
            abi.encodePacked(REMOTE_TOKEN, keccak256(abi.encode(L1_STANDARD_BRIDGE_PROXY, BALANCES_STORAGE_SLOT)))
        );
        if (success) return abi.decode(result, (uint256)); revert BadL1SLOAD();
        */
    }

    /**
     * x= sqrt(HALF_SLOPE * totalAssets())
     */
    function totalShares() public view returns (uint256) {
        return ud60x18(totalAssets()).div(HALF_SLOPE).sqrt().intoUint256();
    }

    /**
     * @notice Computes the current price of a share, as y = √2Am
     * which is derived from the combination of; y = mx, and A = xy/2
     * where the given values `A` is totalAssets & `m` is the slope of 0.000025
     * @return price The current price along the bonding curve.
     */
    function currentPrice() public view returns (uint256) {
        return ud60x18(totalAssets() * 2).mul(SLOPE).sqrt().intoUint256();
    }

    /**
     * Δx = sqrt(assetTotal/HALF_SLOPE) - sqrt((assetTotal - assetDelta)/HALF_SLOPE)
     * @param assetTotal The current total asset (area under the curve)
     * @param assetDelta The asset amount from user deposit or withdraw
     * @return shares The computed delta in x (shares to mint or burn) given the total assets before and after the transaction
     */
    function _computeShares(UD60x18 assetTotal, UD60x18 assetDelta) private pure returns (UD60x18 shares) {
        return assetTotal.div(HALF_SLOPE).sqrt().sub(assetTotal.sub(assetDelta).div(HALF_SLOPE).sqrt());
    }
}
