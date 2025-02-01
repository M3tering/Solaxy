// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts@5.2.0/interfaces/IERC20.sol";
import {IERC20Errors} from "@openzeppelin/contracts@5.2.0/interfaces/draft-IERC6093.sol";
import {IERC6551Registry, ISolaxy, Solaxy} from "../src/Solaxy.sol";

uint256 constant reserve_balanceOneBillion = 1e9 * 1e18;

contract Handler is Test {
    Solaxy private immutable SLX;
    IERC20 private immutable RESERVE;
    address private immutable HERE;

    constructor(Solaxy slx, IERC20 reserve) {
        (SLX, RESERVE, HERE) = (slx, reserve, address(this));
        RESERVE.approve(address(slx), reserve_balanceOneBillion);
    }

    function deposit(uint256 assets) public {
        assets = bound(assets, 0, 1e20);
        if (assets == 0) vm.expectRevert(ISolaxy.CannotBeZero.selector);
        if (assets > RESERVE.balanceOf(HERE)) vm.expectRevert(IERC20Errors.ERC20InsufficientBalance.selector);
        SLX.deposit(assets, HERE);
    }

    function withdraw(uint256 assets) public {
        assets = bound(assets, 0, 1e20);
        if (assets == 0) vm.expectRevert(ISolaxy.CannotBeZero.selector);
        if (assets > SLX.totalAssets()) vm.expectRevert(ISolaxy.Undersupply.selector);
        SLX.withdraw(assets, HERE, HERE);
    }

    function mint(uint256 shares) public {
        shares = bound(shares, 0, 10e20);
        if (shares == 0) vm.expectRevert(ISolaxy.CannotBeZero.selector);
        SLX.mint(shares, HERE);
    }

    function redeem(uint256 shares) public {
        shares = bound(shares, 0, 1e20);
        if (shares == 0) vm.expectRevert(ISolaxy.CannotBeZero.selector);
        if (shares > SLX.totalSupply()) vm.expectRevert(ISolaxy.Undersupply.selector);
        if (shares > SLX.balanceOf(HERE)) vm.expectRevert(IERC20Errors.ERC20InsufficientBalance.selector);
        SLX.redeem(shares, HERE, HERE);
    }
}

contract SolaxyInvarantTest is Test {
    address public reserve_address;
    Handler public handler;
    IERC20 public RESERVE;
    Solaxy public SLX;
    address public here;
    address public handlerAddress;

    function setUp() public {
        string memory url = vm.rpcUrl("ethereum-mainnet");
        vm.createSelectFork(url);
        here = address(this);

        SLX = new Solaxy();
        reserve_address = SLX.asset();
        RESERVE = IERC20(reserve_address);


        handler = new Handler(SLX, RESERVE);
        handlerAddress = address(handler);

        deal(reserve_address, here, reserve_balanceOneBillion, true);
        dealERC721(address(SLX.M3TER()), handlerAddress, 0);
        targetContract(handlerAddress);
    }

    function invariantValuation() public view {
        uint256 reserve_balanceAfterTest = RESERVE.balanceOf(handlerAddress);
        uint256 solaxyTVL = reserve_balanceOneBillion - reserve_balanceAfterTest;
        assertEq(SLX.totalAssets(), solaxyTVL, "Total value locked should be strictly equal to total reserve assets");

        assertEq(
            SLX.totalSupply(),
            SLX.balanceOf(handlerAddress) + SLX.balanceOf(SLX.tipAccount()),
            "Total handler holdings plus all fees collected should be strictly equal to the total token supply"
        );

        assertApproxEqAbs(
            SLX.totalAssets(),
            SLX.convertToAssets(SLX.totalSupply()),
            0.00001e18,
            "Total reserve assets must be enough to cover the conversion of all existing tokens to less than a cent rounding error"
        );
    }

    function test_knowHolderBalance() public view {
        uint256 knowHolderBalance = RESERVE.balanceOf(0x4e59b44847b379578588920cA78FbF26c0B4956C);
        assertEq(knowHolderBalance, 0.000864e18, "reserve balance should be equal 0.000864 reserve");
    }
}
