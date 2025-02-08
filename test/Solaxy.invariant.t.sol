// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts@5.2.0/interfaces/IERC20.sol";
import {IERC20Errors} from "@openzeppelin/contracts@5.2.0/interfaces/draft-IERC6093.sol";
import {ISolaxy, Solaxy} from "../src/Solaxy.sol";

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
        if (shares > SLX.balanceOf(HERE)) vm.expectRevert(IERC20Errors.ERC20InsufficientBalance.selector);
        SLX.redeem(shares, HERE, HERE);
    }
}

contract SolaxyInvarantTest is Test {
    Solaxy SLX;
    IERC20 RESERVE;
    address RESERVE_address;
    address handlerAddress;
    address constant M3TER_address = 0x9C8fF314C9Bc7F6e59A9d9225Fb22946427eDC03;

    function setUp() public {
        string memory url = vm.rpcUrl("ethereum-mainnet");
        vm.createSelectFork(url);

        SLX = new Solaxy();
        RESERVE_address = SLX.asset();
        RESERVE = IERC20(RESERVE_address);
        handlerAddress = address(new Handler(SLX, RESERVE));

        deal(RESERVE_address, handlerAddress, reserve_balanceOneBillion, true);
        dealERC721(M3TER_address, handlerAddress, 0);
        targetContract(handlerAddress);
    }

    function tipAccount() private view returns (address account) {
        address reg = 0x000000006551c19487814612e58FE06813775758;
        address imp = 0x55266d75D1a14E4572138116aF39863Ed6596E7F;

        (bool success, bytes memory data) = address(reg).staticcall(
            abi.encodeWithSignature("account(address,bytes32,uint256,address,uint256)", imp, 0x0, 1, M3TER_address, 0)
        );
        account = success ? abi.decode(data, (address)) : address(0);
    }

    function invariantValuation() public view {
        assertEq(
            SLX.totalAssets(),
            reserve_balanceOneBillion - RESERVE.balanceOf(handlerAddress),
            "Total value locked should be strictly equal to total reserve assets"
        );

        assertEq(
            SLX.totalSupply(),
            SLX.balanceOf(handlerAddress) + SLX.balanceOf(tipAccount()),
            "Total handler holdings plus all fees collected should be strictly equal to the total token supply"
        );

        assertApproxEqAbs(
            SLX.totalAssets(),
            SLX.previewRedeem(SLX.totalSupply()),
            0.000000002e18,
            "Total reserve assets must be enough to cover the conversion of all existing tokens to less than a cent rounding error"
        );
    }
}
