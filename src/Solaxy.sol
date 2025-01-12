// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.24;

import {UD60x18, ud60x18} from "@prb/math@4.1.0/src/UD60x18.sol";
import {ERC20} from "@openzeppelin/contracts@5.1.0/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts@5.1.0/token/ERC20/extensions/ERC20Permit.sol";
import {ERC20FlashMint} from "@openzeppelin/contracts@5.1.0/token/ERC20/extensions/ERC20FlashMint.sol";

import {IOptimismMintableERC20} from "./interfaces/IOptimismMintableERC20.sol";
import {IERC7802, IERC165} from "./interfaces/IERC7802.sol";
import {ISolaxyView} from "./interfaces/ISolaxy.sol";


/**
 * @title Super Solaxy
 * @author ichristwin.eth
 * @notice Token contract implementing a linear asset-backed bonding curve where the slope is 0.000025.
 * @dev Adheres to ERC-20 token standard and only supports ERC-4626 tokenized vault interface
 * for viewing the bonding curve operations. (view-only)
 * @custom:security-contact 25nzij1r3@mozmail.com
 */
contract SuperSolaxy is ISolaxyView, IOptimismMintableERC20, IERC7802, ERC20Permit, ERC20FlashMint {
    address public constant SUPERCHAIN_TOKEN_BRIDGE = 0x4200000000000000000000000000000000000028;
    address public constant L1_STANDARD_BRIDGE_PROXY = 0x99C9fc46f92E8a1c0deC1b1747d010903E884bE1;
    address public constant L2_STANDARD_BRIDGE = 0x4200000000000000000000000000000000000010;
    address public constant REFI_USD = 0x0d86883FAf4FfD7aEb116390af37746F45b6f378; // ToDo: use refiUSD L1 contract address
    UD60x18 public constant SEMI_SLOPE = UD60x18.wrap(0.0000125e18);

    constructor() ERC20("Solaxy", "SLX") ERC20Permit("Solaxy") {
        if (address(REFI_USD) == address(0)) revert CannotBeZero();
    }

    /**
     * @notice Allows the only the StandardBridge on this L2 to mint shares.
     * @dev Mints shares to receiver who deposited exact underlying assets to the superchain bridge.
     * Functionally equivalent to "ERC4626-deposit" where the superchain bridge L1 contract is the asset vault.
     * @param receiver Address to mint shares to.
     * @param assets Amount deposited to superchain bridge L1 contract.
     */
    function mint(address receiver, uint256 assets) external {
        if (msg.sender != L2_STANDARD_BRIDGE) revert Unauthorized();
        if (assets == 0) revert CannotBeZero();

        uint256 shares = _computeShares(ud60x18(totalAssets()), ud60x18(assets)).intoUint256();
        if (shares == 0) revert CannotBeZero();

        emit Deposit(msg.sender, receiver, assets, shares);
        _mint(receiver, shares);
    }

    /**
     * @notice Allows the only StandardBridge on this L2 to burn shares.
     * @dev Burns shares from owner for withdrawing exact underlying assets from the superchain bridge.
     * Functionally equivalent to "ERC4626-withdraw" where the superchain bridge L1 contract is the asset vault.
     * @param owner Address to burn shares from.
     * @param assets Amount to be withdrawn from superchain bridge L1 contract.
     */
    function burn(address owner, uint256 assets) external {
        if (msg.sender != L2_STANDARD_BRIDGE) revert Unauthorized();
        if (assets == 0) revert CannotBeZero();

        uint256 assetTotal = totalAssets();
        if (assets > assetTotal) revert Undersupply();

        uint256 shares = _computeShares(ud60x18(assetTotal), ud60x18(assets)).intoUint256();
        if (shares > totalSupply()) revert Undersupply();
        if (shares == 0) revert CannotBeZero();

        emit Withdraw(msg.sender, owner, owner, assets, shares);
        _spendAllowance(owner, msg.sender, shares);
        _burn(owner, shares);
    }

    /**
     * @notice Allows the SuperchainTokenBridge to mint shares.
     * @param receiver Address to mint shares to.
     * @param shares Amount of shares to mint.
     */
    function crosschainMint(address receiver, uint256 shares) external {
        if (msg.sender != SUPERCHAIN_TOKEN_BRIDGE) revert Unauthorized();
        emit CrosschainMint(receiver, shares, msg.sender);
        _mint(receiver, shares);
    }

    /**
     * @notice Allows the SuperchainTokenBridge to burn tokens.
     * @param owner Address to burn shares from.
     * @param shares Amount of shares to burn.
     */
    function crosschainBurn(address owner, uint256 shares) external {
        if (msg.sender != SUPERCHAIN_TOKEN_BRIDGE) revert Unauthorized();
        emit CrosschainBurn(owner, shares, msg.sender);
        _spendAllowance(owner, msg.sender, shares);
        _burn(owner, shares);
    }

    /**
     * @notice ERC165 interface check function.
     * @param _interfaceId Interface ID to check.
     * @return Whether or not the interface is supported by this contract.
     */
    function supportsInterface(bytes4 _interfaceId) external view virtual returns (bool) {
        return _interfaceId == type(IERC165).interfaceId || _interfaceId == type(ERC20).interfaceId
            || _interfaceId == type(IERC7802).interfaceId || _interfaceId == type(ISolaxyView).interfaceId
            || _interfaceId == type(IOptimismMintableERC20).interfaceId;
    }

    /**
     * @notice See {IERC4626-convertToShares}.
     */
    function convertToShares(uint256 assets) external view returns (uint256 shares) {
        shares = ud60x18(assets).div(ud60x18(currentPrice())).intoUint256();
    }

    /**
     * @notice See {IERC4626-convertToAssets}.
     */
    function convertToAssets(uint256 shares) external view returns (uint256 assets) {
        assets = ud60x18(shares).mul(ud60x18(currentPrice())).intoUint256();
    }

    /**
     * @notice See {IERC4626-previewDeposit}.
     */
    function previewDeposit(uint256 assets) external view returns (uint256 shares) {
        return _computeShares(ud60x18(totalAssets() + assets), ud60x18(assets)).intoUint256();
    }

    /**
     * @notice See {IERC4626-previewMint}.
     */
    function previewMint(uint256 shares) external view returns (uint256 assets) {
        return ud60x18(totalShares() + shares).powu(2).mul(SEMI_SLOPE).sub(ud60x18(totalAssets())).intoUint256();
    }

    /**
     * @notice See {IERC4626-maxWithdraw}.
     */
    function maxWithdraw(address owner) external view returns (uint256 maxAssets) {
        maxAssets = previewRedeem(balanceOf(owner));
    }

    /**
     * @notice See {IERC4626-previewWithdraw}.
     */
    function previewWithdraw(uint256 assets) external view returns (uint256 shares) {
        return _computeShares(ud60x18(totalAssets()), ud60x18(assets)).intoUint256();
    }

    /**
     * @notice See {IERC4626-maxRedeem}.
     */
    function maxRedeem(address owner) external view returns (uint256 maxShares) {
        return balanceOf(owner);
    }

    /**
     * @notice See {IERC4626-maxDeposit}.
     */
    function maxDeposit(address) external pure returns (uint256 maxAssets) {
        return type(uint256).max;
    }

    /**
     * @notice See {IERC4626-maxMint}.
     */
    function maxMint(address) external pure returns (uint256 maxShares) {
        return type(uint256).max;
    }

    /**
     * @notice See {IERC4626-asset}.
     */
    function asset() external pure returns (address assetTokenAddress) {
        return REFI_USD;
    }

    /**
     * @custom:legacy
     * @notice Legacy getter for REMOTE_TOKEN.
     */
    function remoteToken() external pure returns (address) {
        return REFI_USD;
    }

    /**
     * @custom:legacy
     * @notice Legacy getter for BRIDGE.
     */
    function bridge() external pure returns (address) {
        return L2_STANDARD_BRIDGE;
    }

    /**
     * @notice See {IERC4626-previewRedeem}.
     */
    function previewRedeem(uint256 shares) public view returns (uint256 assets) {
        return ud60x18(totalAssets()).sub(ud60x18(totalShares() - shares).powu(2).mul(SEMI_SLOPE)).intoUint256();
    }

    /**
     * @notice See {IERC4626-totalAssets}.
     * @dev The function is a read of the amount of underlying asset in the superchain bridge L1 contract
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
     * @notice Returns the total amount shares in existence
     * @dev Computed based on the amount of underlying asset in the superchain bridge L1 contract
     * using the formula sqrt(SEMI_SLOPE * totalAssets())
     */
    function totalShares() public view returns (uint256) {
        return ud60x18(totalAssets()).div(SEMI_SLOPE).sqrt().intoUint256();
    }

    /**
     * @notice Returns the current price of a share
     * @dev Computed as y = √2Am which is derived from a combination of the formulae for liner slope & area of a triangle
     * y = mx, and A = xy/2 respectively where the given values `A` is totalAssets & `m` is the slope of 0.000025
     * @return price The current price along the bonding curve.
     */
    function currentPrice() public view returns (uint256) {
        return ud60x18(totalAssets() * 4).mul(SEMI_SLOPE).sqrt().intoUint256();
    }

    /**
     * @dev Given the area under the bonding curve and delta to said area, computes the corresponding delta in x
     * using the formula sqrt(assetTotal/SEMI_SLOPE) - sqrt((assetTotal - assetDelta)/SEMI_SLOPE); Δx = √(A/m') - √((A-z)/m')
     * which is derived from a combination of the formulae for liner slope & area of a triangle; y = mx, and A = xy/2 respectively
     * @param assetTotal The current total asset (area under the curve)
     * @param assetDelta The asset amount from user deposit or withdraw
     * @return shares The computed delta in x (shares to mint or burn) given the total assets before and after the transaction
     */
    function _computeShares(UD60x18 assetTotal, UD60x18 assetDelta) private pure returns (UD60x18 shares) {
        return assetTotal.div(SEMI_SLOPE).sqrt().sub(assetTotal.sub(assetDelta).div(SEMI_SLOPE).sqrt());
    }
}
