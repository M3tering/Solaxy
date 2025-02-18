// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ISolaxy as IERC4626} from "./interfaces/ISolaxy.sol";
import {UD60x18, ud} from "@prb/math@4.1.0/src/UD60x18.sol";
import {ERC20 as Token} from "solady/src/tokens/ERC20.sol";
import {SafeTransferLib} from "solady/src/utils/SafeTransferLib.sol";
import {ReentrancyGuardTransient} from "solady/src/utils/ReentrancyGuardTransient.sol";

/**
 * @title Solaxy
 * @author ichristwin.eth
 * @notice Token contract implementing a linear asset-backed bonding curve where the slope is 0.000025.
 * @dev Adheres to ERC-20 token standard and uses the ERC-4626 tokenized vault interface for bonding curve operations.
 * @custom:security-contact 25nzij1r3@mozmail.com
 */
contract Solaxy is Token, IERC4626, ReentrancyGuardTransient {
    using SafeTransferLib for address;

    address constant RESERVE = 0x6B175474E89094C44Da98b954EedeAC495271d0F; // ToDo: use asset L1 contract address
    address constant M3TER = 0x9C8fF314C9Bc7F6e59A9d9225Fb22946427eDC03; // ToDo: use m3ter L1 contract address
    UD60x18 constant SEMI_SLOPE = UD60x18.wrap(0.0000125e18);

    constructor() Token() {}

    /**
     * @notice Implements {IERC4626-deposit} and protects against slippage by specifying a minimum number of shares to receive.
     * @param minSharesOut The minimum number of shares the sender expects to receive.
     */
    function safeDeposit(uint256 assets, address receiver, uint256 minSharesOut) external returns (uint256 shares) {
        shares = deposit(assets, receiver);
        require(shares > minSharesOut, SlippageError());
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
        require(shares < maxSharesIn, SlippageError());
    }

    /**
     * @notice Implements {IERC4626-deposit} and protects against slippage by specifying a maximum amount of assets to deposit.
     * @param maxAssetsIn The maximum amount of assets the sender is willing to deposit.
     */
    function safeMint(uint256 shares, address receiver, uint256 maxAssetsIn) external returns (uint256 assets) {
        assets = mint(shares, receiver);
        require(shares < maxAssetsIn, SlippageError());
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
        require(shares > minAssetsOut, SlippageError());
    }

    function convertToShares(uint256 assets) external view returns (uint256 shares) {
        shares = ud(assets).div(ud(2 * totalSupply()).mul(SEMI_SLOPE)).unwrap();
    }

    function convertToAssets(uint256 shares) external view returns (uint256 assets) {
        assets = ud(shares).mul(ud(2 * totalSupply()).mul(SEMI_SLOPE)).unwrap();
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
        return RESERVE;
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
        totalManagedAssets = Token(RESERVE).balanceOf(address(this));
    }

    /**
     * @notice Computes the number of shares to be minted for a given amount of assets to be deposited.
     * @dev Utilizes the equation y = sqrt((0.0000125x^2 + A) / 0.0000125) - x, derived from the trapezium area formula.
     */
    function previewDeposit(uint256 assets) public view returns (uint256 shares) {
        UD60x18 totalShares = ud(totalSupply());
        shares = ((totalShares.powu(2) + ud(assets).div(SEMI_SLOPE)).sqrt() - totalShares).unwrap();
    }

    /**
     * @notice Computes the number of shares to be burned for a given amount of assets to be withdrawn.
     * @dev Utilizes the equation y = x - sqrt((0.0000125x^2 - A) / 0.0000125), derived from the trapezium area formula.
     */
    function previewWithdraw(uint256 assets) public view returns (uint256 shares) {
        UD60x18 totalShares = ud(totalSupply());
        shares = (totalShares - (totalShares.powu(2) - (ud(assets).div(SEMI_SLOPE))).sqrt()).unwrap();
    }

    /**
     * @notice Computes the amount of assets to be deposited for a given number of shares minted.
     * @dev Computes assets as the area under a linear curve with a simplified form of the area of a trapezium,
     * f(x) = mx + c, and Area = 1/2 * (a + b) * h;
     * During mint calculates area as SemiSlope * (finalSupply^2 - initialSupply^2), where SemiSlope = (0.000025 / 2)
     */
    function previewMint(uint256 shares) public view returns (uint256 assets) {
        UD60x18 totalShares = ud(totalSupply());
        assets = SEMI_SLOPE.mul((totalShares + ud(shares)).powu(2) - totalShares.powu(2)).unwrap();
    }

    /**
     * @notice Computes the amount of assets to be withdrawn for a given number of shares burned.
     * @dev Computes assets as the area under a linear curve with a simplified form of the area of a trapezium,
     * f(x) = mx + c, and Area = 1/2 * (a + b) * h;
     * During redeem, calculates area as SemiSlope * (initialSupply^2 - finalSupply^2), where SemiSlope = (0.000025 / 2)
     */
    function previewRedeem(uint256 shares) public view returns (uint256 assets) {
        UD60x18 totalShares = ud(totalSupply());
        assets = SEMI_SLOPE.mul(totalShares.powu(2) - (totalShares - ud(shares)).powu(2)).unwrap();
    }

    function name() public pure override returns (string memory) {
        return "Solaxy";
    }

    function symbol() public pure override returns (string memory) {
        return "SLX";
    }

    /**
     * @dev Deposit/mint common workflow. Updates vault balances and handles external to reserve asset contract
     * Reverts if vault balances are not consistent with expectations, only handles consistency checks for vault account
     */
    function _pump(address receiver, uint256 assets, uint256 shares) private nonReentrant {
        (uint256 initialAssets, uint256 initialShares) = (totalAssets(), totalSupply());

        require(assets > 0 && shares > 0, CannotBeZero());
        require(Token(M3TER).balanceOf(receiver) > 0, RequiresM3ter());

        RESERVE.safeTransferFrom(msg.sender, address(this), assets);
        _mint(receiver, shares);

        require(totalAssets() == initialAssets + assets && totalSupply() == initialShares + shares, InconsistentBalances());
        emit Deposit(msg.sender, receiver, assets, shares);
    }

    /**
     * @dev Withdraw/redeem common workflow. Updates vault balances and handles external to reserve asset contract
     * Collects a 7% tip on the underlying asset, taken in shares based on the price of shares after redemption/withdrawal
     * Reverts if vault balances are not consistent with expectations, only handles consistency checks for vault account
     * Tip is computed by finding Z which equal to 7% of X; given that assets is 93% of X, then get it's equivalent in assets
     * i.e  (7/93 * assets) /  (finalSupply * slope)
     */
    function _dump(address receiver, address owner, uint256 assets, uint256 shares) private nonReentrant {
        (uint256 initialAssets, uint256 initialShares) = (totalAssets(), totalSupply());

        uint256 tip = ud(7).div(ud(186)).mul(ud(assets)).div(SEMI_SLOPE.mul(ud(initialShares) - ud(shares))).unwrap();
        require(tip > 0 && assets > 0 && shares > 0, CannotBeZero());
        require(Token(M3TER).balanceOf(receiver) > 0, RequiresM3ter());

        if (msg.sender != owner) _spendAllowance(owner, msg.sender, shares + tip);
        _burn(owner, shares);

        address accImpProxy = 0x55266d75D1a14E4572138116aF39863Ed6596E7F; // @ ERC6551 v0.3.1 account implementation proxy
        (bool success, bytes memory rawTipAccount) = 0x000000006551c19487814612e58FE06813775758.staticcall( // @ ERC6551 v0.3.1 registry
        abi.encodeWithSignature("account(address,bytes32,uint256,address,uint256)", accImpProxy, 0, 1, M3TER, 0));
        require(success, StaticCallFailed());

        _transfer(owner, abi.decode(rawTipAccount, (address)), tip);
        RESERVE.safeTransfer(receiver, assets);

        require(totalAssets() == initialAssets - assets && totalSupply() == initialShares - shares, InconsistentBalances());
        emit Withdraw(msg.sender, receiver, owner, assets, shares);
    }
}
