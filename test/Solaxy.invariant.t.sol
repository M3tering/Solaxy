// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {CommonBase} from "forge-std/Base.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {StdUtils} from "forge-std/StdUtils.sol";
import {Test} from "forge-std/Test.sol";

import {Solaxy} from "../src/Solaxy.sol";
import {IERC20} from "@openzeppelin/contracts@4.9.3/interfaces/IERC20.sol";
import {CannotBeZero, Undersupply} from "../src/interfaces/ISolaxy.sol";

uint256 constant ONE_BILLION_DAI = 1e9 * 1e18;

contract Handler is CommonBase, StdCheats, StdUtils {
    Solaxy private solaxy;
    IERC20 private dai;

    constructor(Solaxy slx, IERC20 Dai) {
        dai = Dai;
        solaxy = slx;
        dai.approve(address(slx), ONE_BILLION_DAI);
    }

    function deposit(uint256 assets) public {
        assets = bound(assets, 1e8, 1e20);
        if (assets == 0) vm.expectRevert(CannotBeZero.selector);
        if (assets > dai.balanceOf(address(this))) vm.expectRevert(bytes("ERC20: transfer amount exceeds balance"));
        solaxy.deposit(assets, address(this));
    }

    function withdraw(uint256 assets) public {
        assets = bound(assets, 1e8, 1e20);
        if (assets == 0) vm.expectRevert(CannotBeZero.selector);
        if (assets > solaxy.totalAssets()) vm.expectRevert(Undersupply.selector);
        solaxy.withdraw(assets, address(this), address(this));
    }

    function mint(uint256 shares) public {
        shares = bound(shares, 1e8, 10e20);
        solaxy.mint(shares, address(this));
    }

    function redeem(uint256 shares) public {
        shares = bound(shares, 1e8, 1e20);
        if (shares > solaxy.totalSupply()) vm.expectRevert(Undersupply.selector);
        if (shares > solaxy.balanceOf(address(this))) vm.expectRevert(bytes("ERC20: transfer amount exceeds balance"));
        solaxy.redeem(shares, address(this), address(this));
    }
}

contract SolaxyInvarantTest is Test {
    Handler public handler;
    Solaxy public slx;
    IERC20 public dai;
    address public slxAddress;
    address public daiAddress;
    address public handlerAddress;

    function setUp() public {
        string memory url = vm.rpcUrl("iotex-mainnet");
        vm.createSelectFork(url, 24_838_201);

        slx = new Solaxy(address(99));
        slxAddress = address(slx);

        daiAddress = slx.asset();
        dai = IERC20(daiAddress);

        handler = new Handler(slx, dai);
        handlerAddress = address(handler);
        deal(daiAddress, handlerAddress, ONE_BILLION_DAI, true);
        targetContract(handlerAddress);
    }

    function invariantValuation() public {
        uint256 daiBalanceAfterTest = dai.balanceOf(handlerAddress);
        uint256 solaxyTVL = ONE_BILLION_DAI - daiBalanceAfterTest;
        assertEq(slx.totalAssets(), solaxyTVL, "Total value locked should be strictly equal to total reserve assets");

        uint256 totalFees = slx.balanceOf(address(99));
        uint256 totalHoldings = slx.balanceOf(handlerAddress);
        assertEq(
            slx.totalSupply(),
            totalHoldings + totalFees,
            "Total user holdings plus all fees collected should be strictly equal to the total token supply"
        );

        assertGe(
            slx.totalAssets(),
            slx.convertToAssets(slx.totalSupply()),
            "Total reserve assets must at least be enough to cover the converstion of all existing tokens"
        );
    }

    // function testKnowAccountHoldingsOnIotexMinnet() public {
    //     uint256 knowHolderBalance = dai.balanceOf(0x6b4b08A879Dc41484438b3a6EAaA628F0Ae8d79f);
    //     assertEq(knowHolderBalance, 200e18);
    // }
}
