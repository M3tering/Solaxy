// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {CommonBase} from "forge-std/Base.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {StdUtils} from "forge-std/StdUtils.sol";
import {Test} from "forge-std/Test.sol";

import {Solaxy} from "../src/Solaxy.sol";
import {IERC20} from "@openzeppelin/contracts@5.0.2/interfaces/IERC20.sol";
import {CannotBeZero, Undersupply} from "../src/interfaces/ISolaxy.sol";

uint256 constant sDAI_balanceOneBillion = 1e9 * 1e18;

contract Handler is CommonBase, StdCheats, StdUtils {
    Solaxy private SLX;
    IERC20 private sDAI;

    constructor(Solaxy slx, IERC20 sdai) {
        SLX = slx;
        sDAI = sdai;
        sDAI.approve(address(slx), sDAI_balanceOneBillion);
    }

    function deposit(uint256 assets) public {
        assets = bound(assets, 1e8, 1e20);
        if (assets == 0) vm.expectRevert(CannotBeZero.selector);
        if (assets > sDAI.balanceOf(address(this))) {
            vm.expectRevert(bytes("ERC20: transfer amount exceeds balance"));
        }
        SLX.deposit(assets, address(this));
    }

    function withdraw(uint256 assets) public {
        assets = bound(assets, 1e8, 1e20);
        if (assets == 0) vm.expectRevert(CannotBeZero.selector);
        if (assets > SLX.totalAssets()) vm.expectRevert(Undersupply.selector);
        SLX.withdraw(assets, address(this), address(this));
    }

    function mint(uint256 shares) public {
        shares = bound(shares, 1e8, 10e20);
        SLX.mint(shares, address(this));
    }

    function redeem(uint256 shares) public {
        shares = bound(shares, 1e8, 1e20);
        if (shares > SLX.totalSupply()) vm.expectRevert(Undersupply.selector);
        if (shares > SLX.balanceOf(address(this))) {
            vm.expectRevert(bytes("ERC20: burn amount exceeds balance"));
        }
        SLX.redeem(shares, address(this), address(this));
    }
}

contract SolaxyInvarantTest is Test {
    Handler public handler;
    Solaxy public SLX;
    IERC20 public sDAI;
    address public SLX_address;
    address public sDAI_address;
    address public handlerAddress;

    function setUp() public {
        string memory url = vm.rpcUrl("gnosis-mainnet");
        vm.createSelectFork(url);

        SLX = new Solaxy();
        SLX_address = address(SLX);

        sDAI_address = SLX.asset();
        sDAI = IERC20(sDAI_address);

        handler = new Handler(SLX, sDAI);
        handlerAddress = address(handler);

        deal(sDAI_address, handlerAddress, sDAI_balanceOneBillion, true);
        dealERC721(address(SLX.M3TER()), handlerAddress, 0);
        targetContract(handlerAddress);
    }

    function invariantValuation() public {
        uint256 sDAI_balanceAfterTest = sDAI.balanceOf(handlerAddress);
        uint256 solaxyTVL = sDAI_balanceOneBillion - sDAI_balanceAfterTest;
        assertEq(SLX.totalAssets(), solaxyTVL, "Total value locked should be strictly equal to total reserve assets");

        uint256 totalFees = SLX.balanceOf(SLX.FEE_ACCOUNT());
        uint256 totalHoldings = SLX.balanceOf(handlerAddress);
        assertEq(
            SLX.totalSupply(),
            totalHoldings + totalFees,
            "Total user holdings plus all fees collected should be strictly equal to the total token supply"
        );

        assertGe(
            SLX.totalAssets() + 1 wei,
            SLX.convertToAssets(SLX.totalSupply()),
            "Total reserve assets must be enough to cover the converstion of all existing tokens with a margin of error of only 1e-18 sDAI"
        );
    }

    function testKnowAccountBalance() public {
        uint256 knowHolderBalance = sDAI.balanceOf(sDAI_address);
        assertApproxEqAbs(knowHolderBalance, 30.5e18, 0.001e18, "sDAI balance should approximately equal 30.49 sDAI");
    }
}
