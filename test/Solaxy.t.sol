// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {stdStorage, StdStorage, Test, console2} from "forge-std/Test.sol";
import {__test_run_DAI as DAI} from "../src/XRC20.sol";
import {Solaxy} from "../src/Solaxy.sol";

contract SolaxyTest is Test {
    DAI public dai;
    Solaxy public slx;
    address public slxAddress;
    address public daiAddress;
    uint256 public slxAmountIn = 6.795e18;
    uint256 public slxAmountMinted = 10e18;
    uint256 public slxAmountBurned = 5e18;
    uint256 public daiAmountDeposited = 0.125e18;
    uint256 public daiAmountWithdrawn = 0.09375e18;

    function setUp() public {
        dai = new DAI();
        daiAddress = address(dai);

        slx = new Solaxy(daiAddress, address(99));
        slxAddress = address(slx);

        dai.approve(slxAddress, dai.totalSupply());
    }

    function testInitialBalanceWithNewSolaxyContract() public {
        uint256 expected = 0;
        uint256 actual = slx.totalSupply();
        assertEq(actual, expected); // New Solaxy contract should have 0 total supply
    }

    function testDepositAndWithdraw() public {
        uint256 initialDaiBalance = dai.balanceOf(slxAddress);
        uint256 initialSlxBalance = slx.balanceOf(address(this));

        // Deposit DAI to Solaxy contract
        slx.deposit(daiAmountDeposited, address(this));
        uint256 slxSupplyAfterDeposit = slx.totalSupply();
        uint256 daiBalanceAfterDeposit = dai.balanceOf(slxAddress);
        uint256 slxBalanceAfterDeposit = slx.balanceOf(address(this));

        assertEq(initialDaiBalance, 0); // DAI balance should be 0 before deposit
        assertEq(initialSlxBalance, 0); // SLX balance should be 0 before deposit
        assertEq(slxSupplyAfterDeposit, slxAmountMinted); // SLX supply should increase after deposit
        assertEq(slxBalanceAfterDeposit, slxAmountMinted); // SLX balance should increase after deposit
        assertEq(daiBalanceAfterDeposit, daiAmountDeposited); // DAI balance should decrease after deposit

        // Withdraw DAI from Solaxy contract
        slx.withdraw(daiAmountWithdrawn, address(this), address(this));
        uint256 slxSupplyAfterWithdraw = slx.totalSupply();
        uint256 daiBalanceAfterWithdraw = dai.balanceOf(slxAddress);
        uint256 slxBalanceAfterWithdraw = slx.balanceOf(address(this));

        assertEq(slxBalanceAfterWithdraw, slxBalanceAfterDeposit - slxAmountIn); // SLX balance should decrease after withdrawal
        assertEq(slxSupplyAfterWithdraw, slxSupplyAfterDeposit - slxAmountBurned); // SLX supply should decrease after withdrawal
        assertEq(daiBalanceAfterWithdraw, daiBalanceAfterDeposit - daiAmountWithdrawn); // DAI balance should increase after withdrawal
    }

    function testMintAndRedeem() public {
        uint256 initialDaiBalance = dai.balanceOf(slxAddress);
        uint256 initialSlxBalance = slx.balanceOf(address(this));

        // Mint new SLX tokens
        slx.mint(slxAmountMinted, address(this));
        uint256 slxSupplyAfterMint = slx.totalSupply();
        uint256 daiBalanceAfterMint = dai.balanceOf(slxAddress);
        uint256 slxBalanceAfterMint = slx.balanceOf(address(this));

        assertEq(initialDaiBalance, 0); // DAI balance should be 0 before minting
        assertEq(initialSlxBalance, 0); // SLX balance should be 0 before minting
        assertEq(slxSupplyAfterMint, slxAmountMinted); // SLX supply should increase after minting
        assertEq(slxBalanceAfterMint, slxAmountMinted); // SLX balance should increase after minting
        assertEq(daiBalanceAfterMint, daiAmountDeposited); // DAI balance should decrease after minting

        // Redeem SLX tokens
        slx.redeem(slxAmountIn, address(this), address(this));
        uint256 slxSupplyAfterRedeem = slx.totalSupply();
        uint256 daiBalanceAfterRedeem = dai.balanceOf(slxAddress);
        uint256 slxBalanceAfterRedeem = slx.balanceOf(address(this));

        assertApproxEqAbs(slxBalanceAfterRedeem, slxBalanceAfterMint - slxAmountIn, 0.002e18); // SLX balance should decrease after redeeming
        assertApproxEqAbs(slxSupplyAfterRedeem, slxSupplyAfterMint - slxAmountBurned, 0.002e18); // SLX supply should decrease after redeeming
        assertApproxEqAbs(daiBalanceAfterRedeem, daiBalanceAfterMint - daiAmountWithdrawn, 0.002e18); // DAI balance should increase after redeeming
    }
}
