// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {CommonBase} from "forge-std/Base.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {StdUtils} from "forge-std/StdUtils.sol";
import {Test} from "forge-std/Test.sol";

import {Solaxy} from "../src/Solaxy.sol";
import {IERC20} from "@openzeppelin/contracts@4.9.3/interfaces/IERC20.sol";

contract Handler is CommonBase, StdCheats, StdUtils {
    Solaxy private solaxy;
    IERC20 private dai;

    constructor(Solaxy slx, IERC20 Dai) {
        solaxy = slx;
        dai = Dai;
    }

    function deposit(uint256 assets) public {
        assets = bound(assets, 1e14, dai.balanceOf(address(this)));
        solaxy.deposit(assets, address(this));
    }

    function withdraw(uint256 assets) public {
        assets = bound(assets, 1e14, solaxy.totalAssets());
        solaxy.withdraw(assets, address(this), address(this));
    }

    function mint(uint256 shares) public {
        solaxy.mint(shares, address(this));
    }

    function redeem(uint256 shares) public {
        shares = bound(shares, 1e14, solaxy.balanceOf(address(this)));
        solaxy.redeem(shares, address(this), address(this));
    }
}

contract SolaxyInvarantTest is Test {
    Handler public handler;
    Solaxy public slx;
    IERC20 public dai;
    address public here;
    address public slxAddress;
    address public daiAddress;
    uint256 public constant oneMillionDaiBalance = 1e6 * 1e18;

    function setUp() public {
        vm.createSelectFork("https://babel-api.mainnet.iotex.io/", 24_838_201);
        here = address(this);

        slx = new Solaxy(address(99));
        slxAddress = address(slx);

        daiAddress = slx.asset();
        dai = IERC20(daiAddress);

        deal(daiAddress, here, oneMillionDaiBalance, true);
        dai.approve(slxAddress, oneMillionDaiBalance);

        handler = new Handler(slx, dai);
        targetContract(address(handler));
    }

    function invariantValuation() public {
        uint256 daiBalanceAfterTest = dai.balanceOf(slxAddress);
        uint256 solaxyTVL = oneMillionDaiBalance - daiBalanceAfterTest;
        assertEq(slx.totalAssets(), solaxyTVL, "Total value locked should be strictly equal to total reserve assets");

        uint256 totalFees = slx.balanceOf(address(99));
        uint256 totalHoldings = slx.balanceOf(here);
        assertEq(
            slx.totalSupply(),
            totalHoldings + totalFees,
            "Total user holdings plus all fees collected should be strictly equal to the total token supply"
        );

        assertEq(
            slx.totalAssets(),
            slx.convertToAssets(slx.totalSupply()),
            "Total reserve assets should strictly cover the converstion of all existing tokens"
        );
    }
}
