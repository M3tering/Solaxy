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
    Solaxy public SLX;
    IERC20 public RESERVE;
    address public RESERVE_address;
    address public handlerAddress;

    function setUp() public {
        string memory url = vm.rpcUrl("ethereum-mainnet");
        vm.createSelectFork(url);

        SLX = new Solaxy();
        RESERVE_address = SLX.asset();
        RESERVE = IERC20(RESERVE_address);
        handlerAddress = address(new Handler(SLX, RESERVE));

        deal(RESERVE_address, handlerAddress, reserve_balanceOneBillion, true);
        dealERC721(address(SLX.M3TER()), handlerAddress, 0);
        targetContract(handlerAddress);
    }

    function invariantValuation() public view {
        assertEq(
            SLX.totalAssets(),
            RESERVE.balanceOf(handlerAddress) - reserve_balanceOneBillion,
            "Total value locked should be strictly equal to total reserve assets"
        );

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
}
