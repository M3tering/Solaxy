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
    address private immutable USER;

    constructor(Solaxy slx, IERC20 reserve, address user) {
        (SLX, RESERVE, USER) = (slx, reserve, user);
        vm.prank(user);
        RESERVE.approve(address(slx), reserve_balanceOneBillion); // approve user
    }

    function deposit(uint256 assets) public {
        assets = bound(assets, 0, 1e20);
        if (assets == 0) vm.expectRevert(ISolaxy.CannotBeZero.selector);
        if (assets > RESERVE.balanceOf(USER)) vm.expectRevert(IERC20Errors.ERC20InsufficientBalance.selector);
        vm.startPrank(USER);
        SLX.deposit(assets, USER);
    }

    function withdraw(uint256 assets) public {
        assets = bound(assets, 0, 1e20);
        if (assets == 0) vm.expectRevert(ISolaxy.CannotBeZero.selector);
        if (assets > SLX.totalAssets()) vm.expectRevert(ISolaxy.Undersupply.selector);
        vm.startPrank(USER);
        SLX.withdraw(assets, USER, USER);
    }

    function mint(uint256 shares) public {
        shares = bound(shares, 0, 10e20);
        if (shares == 0) vm.expectRevert(ISolaxy.CannotBeZero.selector);
        vm.startPrank(USER);
        SLX.mint(shares, USER);
    }

    function redeem(uint256 shares) public {
        shares = bound(shares, 0, 1e20);
        if (shares == 0) vm.expectRevert(ISolaxy.CannotBeZero.selector);
        if (shares > SLX.totalSupply()) vm.expectRevert(ISolaxy.Undersupply.selector);
        if (shares > SLX.balanceOf(USER)) vm.expectRevert(IERC20Errors.ERC20InsufficientBalance.selector);
        vm.startPrank(USER);
        SLX.redeem(shares, USER, USER);
    }
}

contract SolaxyInvarantTest is Test {
    address public reserve_address;
    address public user;
    Handler public handler;
    IERC20 public reserve;
    Solaxy public SLX;

    function setUp() public {
        string memory url = vm.rpcUrl("ethereum-mainnet");
        vm.createSelectFork(url);

        SLX = new Solaxy();
        reserve_address = SLX.asset();
        reserve = IERC20(reserve_address);

        // ERC6551@v0.3.1 Registry contract & Implementation Proxy addresses respectively
        // Note that account wouldn't work as expected unless deployed and properly initialized (if proxy)
        user = IERC6551Registry(0x000000006551c19487814612e58FE06813775758).account(
            0x780e323E6120a0b4A47089f6395a0B809d8C2845, 0x0, 1, SLX.M3TER(), 0
        );
        deal(reserve_address, user, reserve_balanceOneBillion, true); // deal user
        targetContract(address(new Handler(SLX, reserve, user)));
    }

    function invariantValuation() public view {
        uint256 reserve_balanceAfterTest = reserve.balanceOf(user);
        uint256 solaxyTVL = reserve_balanceOneBillion - reserve_balanceAfterTest;
        assertEq(SLX.totalAssets(), solaxyTVL, "Total value locked should be strictly equal to total reserve assets");

        assertEq(
            SLX.totalSupply(),
            SLX.balanceOf(user) + SLX.balanceOf(SLX.tipAccount()),
            "Total user holdings plus all fees collected should be strictly equal to the total token supply"
        );

        assertApproxEqAbs(
            SLX.totalAssets(),
            SLX.convertToAssets(SLX.totalSupply()),
            0.00001e18,
            "Total reserve assets must be enough to cover the conversion of all existing tokens to less than a cent rounding error"
        );
    }

    function test_knowHolderBalance() public view {
        uint256 knowHolderBalance = reserve.balanceOf(0x4e59b44847b379578588920cA78FbF26c0B4956C);
        assertEq(knowHolderBalance, 0.000864e18, "reserve balance should approximately equal 30.49 reserve");
    }
}
