// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {Solaxy} from "../src/Solaxy.sol";
import {PayableErr} from "../src/interfaces/ISolaxy.sol";
import {IERC20} from "@openzeppelin/contracts@4.9.3/interfaces/IERC20.sol";

contract SolaxyTest is Test {
    Solaxy public slx;
    IERC20 public dai;
    address public here;
    address public slxAddress;
    address public daiAddress;
    uint256 public constant slxAmountIn = 6.795e18;
    uint256 public constant slxAmountMinted = 10e18;
    uint256 public constant slxAmountBurned = 5e18;
    uint256 public constant daiAmountDeposited = 0.125e18;
    uint256 public constant daiAmountWithdrawn = 0.09375e18;
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
    }

    function testInitialBalanceWithNewSolaxyContract() public {
        uint256 expected = 0;
        uint256 actual = slx.totalSupply();
        assertEq(actual, expected, "New Solaxy contract should have 0 total supply");
    }

    function testSendEtherToContract() public {
        vm.expectRevert(PayableErr.selector); // expect a transaction revert during test.
        payable(slxAddress).transfer(1 ether); // Sending 1 Ether to the contract
        assertEq(slxAddress.balance, 0 ether, "asset ether balance is still equal to zero");
    }

    function testDepositAndWithdraw() public {
        uint256 initialDaiBalance = dai.balanceOf(slxAddress);
        uint256 initialSlxBalance = slx.balanceOf(here);

        // Deposit DAI to Solaxy contract
        slx.deposit(daiAmountDeposited, here);
        uint256 slxSupplyAfterDeposit = slx.totalSupply();
        uint256 daiBalanceAfterDeposit = dai.balanceOf(slxAddress);
        uint256 slxBalanceAfterDeposit = slx.balanceOf(here);

        assertEq(initialDaiBalance, 0, "DAI balance should be 0 before deposit");
        assertEq(initialSlxBalance, 0, "SLX balance should be 0 before deposit");
        assertEq(slxSupplyAfterDeposit, slxAmountMinted, "SLX supply should increase after deposit");
        assertEq(slxBalanceAfterDeposit, slxAmountMinted, "SLX balance should increase after deposit");
        assertEq(daiBalanceAfterDeposit, daiAmountDeposited, "DAI balance should decrease after deposit");

        // convert to shares
        uint256 convertedShares = slx.convertToShares(daiAmountDeposited);
        assertEq(convertedShares, slxAmountBurned);

        // Withdraw DAI from Solaxy contract
        slx.withdraw(daiAmountWithdrawn, here, here);
        uint256 slxSupplyAfterWithdraw = slx.totalSupply();
        uint256 daiBalanceAfterWithdraw = dai.balanceOf(slxAddress);
        uint256 slxBalanceAfterWithdraw = slx.balanceOf(here);

        assertEq(
            slxBalanceAfterWithdraw,
            slxBalanceAfterDeposit - slxAmountIn,
            "SLX balance should decrease after withdrawal"
        );
        assertEq(
            slxSupplyAfterWithdraw,
            slxSupplyAfterDeposit - slxAmountBurned,
            "SLX supply should decrease after withdrawal"
        );
        assertEq(
            daiBalanceAfterWithdraw,
            daiBalanceAfterDeposit - daiAmountWithdrawn,
            "DAI balance should increase after withdrawal"
        );

        // Check for fees
        uint256 feeSlxBalance = slx.balanceOf(address(99));
        assertEq(feeSlxBalance, 1795000000000000000);
    }

    function testMintAndRedeem() public {
        uint256 initialDaiBalance = dai.balanceOf(slxAddress);
        uint256 initialSlxBalance = slx.balanceOf(here);

        // Mint new SLX tokens
        slx.mint(slxAmountMinted, here);
        uint256 slxSupplyAfterMint = slx.totalSupply();
        uint256 daiBalanceAfterMint = dai.balanceOf(slxAddress);
        uint256 slxBalanceAfterMint = slx.balanceOf(here);

        assertEq(initialDaiBalance, 0, "DAI balance should be 0 before minting");
        assertEq(initialSlxBalance, 0, "SLX balance should be 0 before minting");
        assertEq(slxSupplyAfterMint, slxAmountMinted, "SLX supply should increase after minting");
        assertEq(slxBalanceAfterMint, slxAmountMinted, "SLX balance should increase after minting");
        assertEq(daiBalanceAfterMint, daiAmountDeposited, "DAI balance should decrease after minting");

        // convert to assets
        uint256 convertedAssets = slx.convertToAssets(slxAmountBurned);
        assertEq(convertedAssets, daiAmountDeposited);

        // Redeem SLX tokens
        slx.redeem(slxAmountIn, here, here);
        uint256 slxSupplyAfterRedeem = slx.totalSupply();
        uint256 daiBalanceAfterRedeem = dai.balanceOf(slxAddress);
        uint256 slxBalanceAfterRedeem = slx.balanceOf(here);

        assertApproxEqAbs(
            slxBalanceAfterRedeem,
            slxBalanceAfterMint - slxAmountIn,
            0.002e18,
            "SLX balance should decrease after redeeming"
        );
        assertApproxEqAbs(
            slxSupplyAfterRedeem,
            slxSupplyAfterMint - slxAmountBurned,
            0.002e18,
            "SLX supply should decrease after redeeming"
        );
        assertApproxEqAbs(
            daiBalanceAfterRedeem,
            daiBalanceAfterMint - daiAmountWithdrawn,
            0.002e18,
            "DAI balance should increase after redeeming"
        );

        // Check for fees
        uint256 feeSlxBalance = slx.balanceOf(address(99));
        assertEq(feeSlxBalance, 1793880000000000000);
    }
}
